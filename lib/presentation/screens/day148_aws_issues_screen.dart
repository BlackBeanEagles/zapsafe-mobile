/// Day 148 — Fix AWS-Specific Issues
///
/// Day 147 testing revealed 6 categories of AWS issues.
/// These are backend-side fixes (the frontend detects and handles them),
/// but the Flutter app needs to be robust against each:
///
///   Issue 1 — CORS errors on certain WebView / hybrid calls
///   Issue 2 — SSL certificate mismatch on api-aws subdomain
///   Issue 3 — Slow DB queries (2s vs 100ms on DigitalOcean)
///   Issue 4 — Lambda cold start (5s first request, then 100ms)
///   Issue 5 — Rate limiting (AWS throttles at 100 req/sec)
///   Issue 6 — Region latency (users far from ap-south-1)
///
/// Frontend work: update error handling, add retry logic, show
/// graceful degradation, and add CloudFront CDN integration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider   = StateProvider<int>((ref) => 0);
final _fixedProvider       = StateProvider<List<bool>>(
  (ref) => List.filled(6, false),
);
final _cwLogProvider       = StateProvider<_CwState>((ref) => _CwState.idle);
final _demoIssueProvider   = StateProvider<int?>((ref) => null);
final _demoStateProvider   = StateProvider<_DemoState>((ref) => _DemoState.idle);

enum _CwState  { idle, loading, done }
enum _DemoState { idle }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Issue {
  final String  id;
  final String  title;
  final Color   color;
  final IconData icon;
  final String  symptom;      // what the app/user sees
  final String  rootCause;
  final String  backendFix;   // what the backend team does
  final String  frontendFix;  // what we change in Flutter
  final String  codeFile;
  final String  codeBefore;
  final String  codeAfter;
  final bool    backendOnly;  // true = only backend fix needed
  const _Issue({
    required this.id,
    required this.title,
    required this.color,
    required this.icon,
    required this.symptom,
    required this.rootCause,
    required this.backendFix,
    required this.frontendFix,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
    this.backendOnly = false,
  });
}

const _kIssues = [
  _Issue(
    id: 'I1',
    title: 'CORS Errors on WebView calls',
    color: Color(0xFFEF4444),
    icon: Icons.block_rounded,
    symptom: 'WebLink contact view crashes with "XMLHttpRequest blocked '
        'by CORS policy". The django CORS_ALLOWED_ORIGINS list on AWS '
        'did not include the new api-aws subdomain.',
    rootCause: 'AWS deployment uses a different origin than DigitalOcean. '
        'Django-CORS-Headers was configured with the old domain only.',
    backendFix: 'Add api-aws.zapsafe.app to CORS_ALLOWED_ORIGINS in '
        'settings/aws.py. Redeploy.',
    frontendFix: 'Wrap WebView requests in try-catch; show "Loading…" '
        'skeleton until CORS is confirmed fixed on backend.',
    codeFile: 'weblink_screen.dart',
    codeBefore:
        '// ❌ No error handling for CORS failures\n'
        'WebViewController controller = WebViewController()\n'
        '  ..loadRequest(Uri.parse(weblinkUrl));',
    codeAfter:
        '// ✅ Graceful CORS error handling\n'
        'WebViewController controller = WebViewController()\n'
        '  ..setNavigationDelegate(NavigationDelegate(\n'
        '    onWebResourceError: (err) {\n'
        '      if (err.errorCode == -1 ||\n'
        '          err.description.contains(\'CORS\')) {\n'
        '        setState(() => _showCorsError = true);\n'
        '      }\n'
        '    },\n'
        '  ))\n'
        '  ..loadRequest(Uri.parse(weblinkUrl));',
  ),
  _Issue(
    id: 'I2',
    title: 'SSL Certificate Mismatch',
    color: Color(0xFFF97316),
    icon: Icons.lock_open_rounded,
    symptom: 'OkHttp throws "Certificate verification failed" on '
        'api-aws.zapsafe.app. AWS initially provisioned a wildcard cert '
        '*.zapsafe.app — OkHttp rejects this for a bare subdomain.',
    rootCause: 'AWS Certificate Manager wildcard cert covers *.zapsafe.app '
        'but OkHttp strict mode requires an exact match or SAN entry for '
        'api-aws.zapsafe.app.',
    backendFix: 'Issue a dedicated ACM cert for api-aws.zapsafe.app with '
        'the exact subdomain in the SANs. Attach to ALB.',
    frontendFix: 'Add certificate pin for api-aws.zapsafe.app SHA-256 digest '
        'to network_security_config.xml (temporary) until cert rotated.',
    codeFile: 'network_security_config.xml',
    codeBefore:
        '<!-- Before: no pin -->\n'
        '<network-security-config>\n'
        '  <base-config />\n'
        '</network-security-config>',
    codeAfter:
        '<!-- Temporary pin until ACM cert issued -->\n'
        '<network-security-config>\n'
        '  <domain-config>\n'
        '    <domain>api-aws.zapsafe.app</domain>\n'
        '    <pin-set expiration="2026-12-31">\n'
        '      <pin digest="SHA-256">AWS_ALB_CERT_SHA256</pin>\n'
        '    </pin-set>\n'
        '  </domain-config>\n'
        '</network-security-config>',
    backendOnly: false,
  ),
  _Issue(
    id: 'I3',
    title: 'Slow DB Queries (2s vs 100ms)',
    color: Color(0xFFF59E0B),
    icon: Icons.speed_rounded,
    symptom: 'Dashboard takes 2.1s to load on AWS vs 95ms on DigitalOcean. '
        'CloudWatch slow query log shows full table scans on '
        'sos_events and gps_traces tables.',
    rootCause: 'AWS RDS PostgreSQL instance is a new blank DB — '
        'the TimescaleDB indexes created on DigitalOcean were not '
        'migrated. Full table scan on 50k GPS rows.',
    backendFix: 'Run index migration on RDS: CREATE INDEX CONCURRENTLY on '
        'gps_traces(event_id, timestamp) and sos_events(user_id, created_at). '
        'Add EXPLAIN ANALYZE to CI pipeline.',
    frontendFix: 'Add skeleton loaders with a 3s timeout. If response takes '
        '> 1s, show "Loading your data…" progress indicator.',
    codeFile: 'dashboard_provider.dart',
    codeBefore:
        '// ❌ Hangs visibly while AWS RDS runs full table scan\n'
        'final data = await api.get(\'/api/v1/analytics/summary/\');',
    codeAfter:
        '// ✅ Timeout + skeleton during slow AWS queries\n'
        'final data = await api\n'
        '    .get(\'/api/v1/analytics/summary/\')\n'
        '    .timeout(\n'
        '      const Duration(seconds: 5),\n'
        '      onTimeout: () => throw TimeoutException(\'Slow query\'),\n'
        '    );',
    backendOnly: false,
  ),
  _Issue(
    id: 'I4',
    title: 'Lambda Cold Start (5s first request)',
    color: Color(0xFF8B5CF6),
    icon: Icons.ac_unit_rounded,
    symptom: 'First SOS trigger after idle period takes 5.2s instead '
        'of < 500ms. CloudWatch shows Lambda initialisation time of 4.8s '
        'on cold containers.',
    rootCause: 'AWS Lambda functions are serverless — containers are '
        'recycled after inactivity. Re-initialising Django takes 4-5s. '
        'EKS (Kubernetes) pods do not have this issue — but the PDF '
        'export and evidence processing functions use Lambda.',
    backendFix: 'Enable Provisioned Concurrency on Lambda for SOS + '
        'evidence functions. Keep 2 warm containers at all times.',
    frontendFix: 'For SOS trigger: show "Connecting to safety network…" '
        'spinner instead of blank screen during Lambda cold start.',
    codeFile: 'sos_service.dart',
    codeBefore:
        '// ❌ No cold-start feedback — blank screen for 5s\n'
        'await api.post(\'/api/v1/sos/trigger/\', body: payload);',
    codeAfter:
        '// ✅ Show progress during Lambda cold start\n'
        '_showStatus(\'Connecting to safety network…\');\n'
        'try {\n'
        '  await api.post(\'/api/v1/sos/trigger/\', body: payload)\n'
        '      .timeout(const Duration(seconds: 10));\n'
        '  _showStatus(\'SOS sent — contacts notified\');\n'
        '} on TimeoutException {\n'
        '  _showStatus(\'Retrying…\');\n'
        '  await Future.delayed(const Duration(milliseconds: 500));\n'
        '  await api.post(\'/api/v1/sos/trigger/\', body: payload);\n'
        '}',
    backendOnly: false,
  ),
  _Issue(
    id: 'I5',
    title: 'Rate Limiting (429 on high traffic)',
    color: Color(0xFF3B82F6),
    icon: Icons.speed_rounded,
    symptom: 'During a simulated 200-concurrent-user load test, '
        'GPS batch upload returns HTTP 429 "Too Many Requests". '
        'AWS API Gateway default quota: 100 req/sec.',
    rootCause: 'AWS API Gateway throttle limit was left at the default '
        '100 req/sec. With 847 beta testers sending GPS batches every '
        '30s, peak can exceed this.',
    backendFix: 'Increase API Gateway usage plan limit to 10,000 req/sec '
        'for all ZapSafe routes. Set burst limit to 5,000.',
    frontendFix: 'Add exponential back-off retry on 429 responses. '
        'Queue GPS batches locally and retry after delay.',
    codeFile: 'gps_batch_service.dart',
    codeBefore:
        '// ❌ Fails silently on 429\n'
        'await api.post(\'/api/v1/gps/batch/\', body: batch);',
    codeAfter:
        '// ✅ Exponential back-off on 429\n'
        'Future<void> _uploadWithRetry(List<GpsPoint> batch,\n'
        '    {int attempt = 0}) async {\n'
        '  try {\n'
        '    await api.post(\'/api/v1/gps/batch/\', body: batch);\n'
        '  } on ApiException catch (e) {\n'
        '    if (e.statusCode == 429 && attempt < 3) {\n'
        '      final delay = Duration(seconds: 1 << attempt); // 1,2,4s\n'
        '      await Future.delayed(delay);\n'
        '      return _uploadWithRetry(batch, attempt: attempt + 1);\n'
        '    }\n'
        '    rethrow;\n'
        '  }\n'
        '}',
    backendOnly: false,
  ),
  _Issue(
    id: 'I6',
    title: 'Region Latency (users outside Mumbai)',
    color: Color(0xFF10B981),
    icon: Icons.public_rounded,
    symptom: 'API calls from users in Delhi average 48ms (good). '
        'Users in Bangalore average 110ms, Chennai 95ms, '
        'but users in Tier-3 cities (rural India) see 280-400ms.',
    rootCause: 'All traffic routes to ap-south-1 (Mumbai) directly. '
        'No CDN or edge caching. Static assets (translations, '
        'model files) re-downloaded on every new session.',
    backendFix: 'Enable CloudFront distribution with Mumbai as origin. '
        'Cache static API responses (heatmap tiles, translations) '
        'at edge for 60s TTL.',
    frontendFix: 'Switch static asset base URL to CloudFront domain. '
        'Add ETag-based cache headers to Dio interceptor.',
    codeFile: 'api_config.dart',
    codeBefore:
        '// ❌ All assets served from AWS origin\n'
        'static const staticUrl =\n'
        '    \'https://api-aws.zapsafe.app/static/\';',
    codeAfter:
        '// ✅ Static assets via CloudFront CDN\n'
        'static const staticUrl =\n'
        '    \'https://cdn.zapsafe.app/\';  // CloudFront\n'
        '\n'
        '// Dio interceptor adds ETag caching\n'
        'options.headers[\'Cache-Control\'] = \'max-age=60\';',
    backendOnly: false,
  ),
];

const _kCloudWatchLogs = [
  '2026-06-18 09:14:22 [ERROR] CORS preflight rejected from api-aws.zapsafe.app',
  '2026-06-18 09:14:23 [WARN]  SSL handshake failed: certificate mismatch',
  '2026-06-18 09:14:31 [SLOW]  query sos_events: 2148ms (full scan, no index)',
  '2026-06-18 09:14:45 [INIT]  Lambda cold start: 4820ms (pdf_export fn)',
  '2026-06-18 09:15:02 [429]   Rate limit exceeded: /api/v1/gps/batch/ 147 req/s',
  '2026-06-18 09:15:18 [INFO]  Request from rural-IN: 312ms latency (no CDN)',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day148AwsIssuesScreen extends ConsumerWidget {
  const Day148AwsIssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab   = ref.watch(_activeTabProvider);
    final fixed = ref.watch(_fixedProvider);
    final allDone = fixed.every((f) => f);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 148 · Fix AWS Issues'),
        elevation: 0,
        actions: [
          if (allDone)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Text('All fixed ✅',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _CloudWatchTab(),
            if (tab == 1) _IssuesTab(fixed: fixed),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0808), Color(0xFF0D0404), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 148', const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('AWS Phase · Day 8/10', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Fix AWS-Specific\nIssues',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'CloudWatch revealed 6 issues after migrating from DigitalOcean. '
            'CORS · SSL · slow queries · Lambda cold start · '
            'rate limits · region latency. '
            'Frontend handles each gracefully; backend team fixes the root causes.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('6',       'Issues found',   Color(0xFFEF4444)),
            _HStat('Backend', '+ Frontend',     Color(0xFFF97316)),
            _HStat('Retry',   'Back-off logic', Color(0xFF3B82F6)),
            _HStat('CDN',     'CloudFront',     Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.cloud_rounded,     Color(0xFFEF4444), 'CloudWatch'),
      (Icons.build_rounded,     Color(0xFF3B82F6), 'Fix Issues'),
    ];
    return Row(
      children: List.generate(2, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i == 0 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isActive ? color : const Color(0xFF6B7280), size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: isActive ? color : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── CloudWatch Tab ─────────────────────────────────────────────────────────────
class _CloudWatchTab extends ConsumerWidget {
  const _CloudWatchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cwState = ref.watch(_cwLogProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.cloud_rounded,
          color: const Color(0xFFEF4444),
          text: 'AWS CloudWatch captured errors in the first hour after '
              'switching to AWS. Pull the logs to see what broke.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('aws-cli',
            '# Pull CloudWatch error logs\n'
            'aws logs filter-log-events \\\n'
            '  --log-group-name /ecs/zapsafe-backend \\\n'
            '  --filter-pattern "ERROR OR WARN OR SLOW OR 429" \\\n'
            '  --start-time \$(date -d \'1 hour ago\' +%s000)\n'
            '\n'
            '# Or use the AWS Console:\n'
            '# CloudWatch → Log Groups → /ecs/zapsafe-backend → Insights'),
        const SizedBox(height: ZapSpacing.lg),

        if (cwState == _CwState.idle)
          _actionButton(
            label: 'Pull CloudWatch error logs',
            icon: Icons.cloud_download_rounded,
            color: const Color(0xFFEF4444),
            onTap: () async {
              ref.read(_cwLogProvider.notifier).state = _CwState.loading;
              await Future.delayed(const Duration(milliseconds: 1200));
              if (!context.mounted) return;
              ref.read(_cwLogProvider.notifier).state = _CwState.done;
            },
          )
        else if (cwState == _CwState.loading)
          _statusChip(Icons.hourglass_top_rounded, const Color(0xFFEF4444),
              'Fetching CloudWatch logs…', loading: true)
        else ...[
          _statusChip(Icons.check_circle_rounded, const Color(0xFFEF4444),
              '6 issues found — switch to Fix Issues tab'),
          const SizedBox(height: ZapSpacing.lg),
          // Log output
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1C2128),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('CloudWatch · /ecs/zapsafe-backend',
                        style: TextStyle(
                            color: Color(0xFF79C0FF), fontSize: 10,
                            fontFamily: 'monospace')),
                  ),
                ]),
                const SizedBox(height: ZapSpacing.md),
                ..._kCloudWatchLogs.map((line) {
                  Color lineColor = const Color(0xFFE6EDF3);
                  if (line.contains('[ERROR]')) lineColor = const Color(0xFFFF7B72);
                  if (line.contains('[WARN]'))  lineColor = const Color(0xFFFFA657);
                  if (line.contains('[SLOW]'))  lineColor = const Color(0xFFE3B341);
                  if (line.contains('[429]'))   lineColor = const Color(0xFFFF7B72);
                  if (line.contains('[INIT]'))  lineColor = const Color(0xFFD2A8FF);
                  if (line.contains('[INFO]'))  lineColor = const Color(0xFF9CA3AF);

                  // Map log line to issue ID
                  final issueId = line.contains('CORS')    ? 'I1'
                      : line.contains('SSL')     ? 'I2'
                      : line.contains('SLOW')    ? 'I3'
                      : line.contains('INIT')    ? 'I4'
                      : line.contains('429')     ? 'I5'
                      : line.contains('latency') ? 'I6'
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(line,
                              style: TextStyle(
                                  color: lineColor, fontSize: 10,
                                  fontFamily: 'monospace', height: 1.4)),
                        ),
                        if (issueId != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: lineColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(issueId,
                                style: TextStyle(
                                    color: lineColor, fontSize: 8,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          // Issue summary
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: _kIssues.asMap().entries.map((e) {
                final i       = e.key;
                final issue   = e.value;
                final isLast  = i == _kIssues.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md, vertical: 10),
                    child: Row(children: [
                      Container(
                        width: 22,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 2),
                        decoration: BoxDecoration(
                          color: issue.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(issue.id,
                            style: TextStyle(
                                color: issue.color, fontSize: 8,
                                fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(issue.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                      Icon(issue.icon, color: issue.color, size: 14),
                    ]),
                  ),
                  if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Issues Tab ─────────────────────────────────────────────────────────────────
class _IssuesTab extends ConsumerWidget {
  final List<bool> fixed;
  const _IssuesTab({required this.fixed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneCount = fixed.where((f) => f).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: doneCount == 6
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: doneCount == 6
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / 6 issues fixed',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  doneCount == 6
                      ? '✅ AWS migration ready'
                      : 'Tap each issue to fix',
                  style: TextStyle(
                      color: doneCount == 6
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / 6,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  doneCount == 6 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Issue cards
        ..._kIssues.asMap().entries.map((e) {
          final i    = e.key;
          final issue= e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _IssueCard(
              issue: issue,
              done: fixed[i],
              onFix: () {
                final updated = List<bool>.from(ref.read(_fixedProvider));
                updated[i] = true;
                ref.read(_fixedProvider.notifier).state = updated;
              },
            ),
          );
        }),

        // All done
        if (doneCount == 6) ...[
          const SizedBox(height: ZapSpacing.lg),
          _doneCard(),
        ],
      ],
    );
  }

  Widget _doneCard() => Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.12),
            const Color(0xFF10B981).withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: Column(children: [
          const Icon(Icons.cloud_done_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('All 6 AWS Issues Fixed ✅',
              style: TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Backend team applied server-side fixes.\n'
            'Frontend error handling updated for all 6 scenarios.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center,
            children: const [
              _Chip('CORS fixed',        Color(0xFFEF4444)),
              _Chip('SSL cert issued',   Color(0xFFF97316)),
              _Chip('DB indexes added',  Color(0xFFF59E0B)),
              _Chip('Lambda warm',       Color(0xFF8B5CF6)),
              _Chip('Rate limit ↑',      Color(0xFF3B82F6)),
              _Chip('CDN live',          Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          _infoBox(
            icon: Icons.arrow_forward_rounded,
            color: const Color(0xFF3B82F6),
            text: 'Day 149: Performance regression test — confirm '
                'AWS latency is within 10% of DigitalOcean baseline.',
          ),
        ]),
      );
}

class _IssueCard extends StatefulWidget {
  final _Issue       issue;
  final bool         done;
  final VoidCallback onFix;
  const _IssueCard({required this.issue, required this.done, required this.onFix});

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.done
            ? const Color(0xFF10B981).withOpacity(0.06)
            : _expanded
                ? issue.color.withOpacity(0.06)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: widget.done
              ? const Color(0xFF10B981).withOpacity(0.35)
              : _expanded
                  ? issue.color.withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.done
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : issue.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.done ? Icons.check_rounded : issue.icon,
                  color: widget.done ? const Color(0xFF10B981) : issue.color,
                  size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: issue.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(issue.id,
                            style: TextStyle(
                                color: issue.color, fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(issue.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    Text(
                      widget.done ? 'Fixed ✅' : issue.symptom,
                      style: TextStyle(
                          color: widget.done
                              ? const Color(0xFF10B981)
                              : const Color(0xFF9CA3AF),
                          fontSize: 10, height: 1.3),
                      maxLines: _expanded ? 10 : 1,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 18),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Column(children: [
                    const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                    // Details
                    _detailRow(Icons.search_rounded,
                        const Color(0xFFEF4444), 'Root cause', issue.rootCause),
                    const SizedBox(height: ZapSpacing.sm),
                    _detailRow(Icons.dns_rounded,
                        const Color(0xFF8B5CF6), 'Backend fix', issue.backendFix),
                    const SizedBox(height: ZapSpacing.sm),
                    _detailRow(Icons.phone_android_rounded,
                        const Color(0xFF3B82F6), 'Frontend fix', issue.frontendFix),
                    const SizedBox(height: ZapSpacing.md),
                    // Code diff
                    _diffBlock(issue.codeFile, issue.codeBefore, issue.codeAfter),
                    const SizedBox(height: ZapSpacing.md),
                    // Apply
                    widget.done
                        ? _statusChip(Icons.check_circle_rounded,
                            const Color(0xFF10B981), '${issue.id} fixed ✅')
                        : _actionButton(
                            label: 'Apply ${issue.id} fix',
                            icon: Icons.build_rounded,
                            color: issue.color,
                            onTap: () async {
                              await Future.delayed(
                                  const Duration(milliseconds: 600));
                              if (!context.mounted) return;
                              widget.onFix();
                              setState(() => _expanded = false);
                            }),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _detailRow(IconData icon, Color color, String label, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: ZapSpacing.sm),
        Text('$label: ',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 10, height: 1.5)),
        ),
      ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]),
    );

Widget _diffBlock(String filename, String before, String after) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF), fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...before.split('\n').map((l) => Text('- $l',
            style: const TextStyle(
                color: Color(0xFFFF7B72), fontSize: 10,
                fontFamily: 'monospace', height: 1.5))),
        const SizedBox(height: 4),
        ...after.split('\n').map((l) => Text('+ $l',
            style: const TextStyle(
                color: Color(0xFF7EE787), fontSize: 10,
                fontFamily: 'monospace', height: 1.5))),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF), fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3), fontSize: 10,
                fontFamily: 'monospace', height: 1.6)),
      ]),
    );
