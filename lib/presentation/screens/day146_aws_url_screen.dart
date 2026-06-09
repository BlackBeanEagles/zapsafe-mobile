/// Day 146 — Switch API Base URL to AWS
///
/// First day of the Days 146-150 AWS Migration phase.
/// The backend team has migrated from DigitalOcean/Fly.io to AWS
/// (ap-south-1, Mumbai). Today the frontend switches its base URL:
///
///   Before: https://api.zapsafe.app   (DigitalOcean)
///   After:  https://api-aws.zapsafe.app  (AWS ALB → EKS)
///
/// Two approaches:
///   A. Hard-code in api_config.dart (simple, rebuild needed to change)
///   B. --dart-define at build time (flexible, no code change needed)
///
/// After switching: verify every request hits the AWS domain via
/// Logcat / console, then run a 5-endpoint smoke test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _approachProvider     = StateProvider<_Approach>((ref) => _Approach.dartDefine);
final _switchStateProvider  = StateProvider<_SwitchState>((ref) => _SwitchState.idle);
final _verifyStateProvider  = StateProvider<_VerifyState>((ref) => _VerifyState.idle);
final _smokeProvider        = StateProvider<List<_SmokeResult?>>(
  (ref) => List.filled(_kSmokeTests.length, null),
);

enum _Approach     { hardCode, dartDefine }
enum _SwitchState  { idle, switching, done }
enum _VerifyState  { idle, verifying, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _SmokeTest {
  final String method;
  final String endpoint;
  final String description;
  final int    expectedStatus;
  final Color  color;
  const _SmokeTest({
    required this.method,
    required this.endpoint,
    required this.description,
    required this.expectedStatus,
    required this.color,
  });
}

class _SmokeResult {
  final int    statusCode;
  final int    latencyMs;
  final bool   pass;
  const _SmokeResult(this.statusCode, this.latencyMs, this.pass);
}

const _kSmokeTests = [
  _SmokeTest(
    method: 'GET', endpoint: '/api/v1/health',
    description: 'Health check — AWS backend alive',
    expectedStatus: 200, color: Color(0xFF10B981),
  ),
  _SmokeTest(
    method: 'POST', endpoint: '/api/v1/auth/otp/request/',
    description: 'Auth: OTP request (non-blocking smoke)',
    expectedStatus: 200, color: Color(0xFF3B82F6),
  ),
  _SmokeTest(
    method: 'GET', endpoint: '/api/v1/user/profile/',
    description: 'User profile from AWS RDS',
    expectedStatus: 200, color: Color(0xFF8B5CF6),
  ),
  _SmokeTest(
    method: 'GET', endpoint: '/api/v1/contacts/',
    description: 'Emergency contacts list from AWS',
    expectedStatus: 200, color: Color(0xFFF59E0B),
  ),
  _SmokeTest(
    method: 'GET', endpoint: '/api/v1/gamification/score/',
    description: 'Gamification score from AWS analytics',
    expectedStatus: 200, color: Color(0xFFF97316),
  ),
];

const _kNetworkLog = [
  '12:04:31.102  D  GET https://api-aws.zapsafe.app/api/v1/health → 200 (45ms)',
  '12:04:31.890  D  POST https://api-aws.zapsafe.app/api/v1/auth/otp/request/ → 200 (182ms)',
  '12:04:32.104  D  GET https://api-aws.zapsafe.app/api/v1/user/profile/ → 200 (78ms)',
  '12:04:32.312  D  GET https://api-aws.zapsafe.app/api/v1/contacts/ → 200 (91ms)',
  '12:04:32.520  D  GET https://api-aws.zapsafe.app/api/v1/gamification/score/ → 200 (67ms)',
  '12:04:32.721  D  ✅ All 5 endpoints → api-aws.zapsafe.app confirmed',
];

const _kSmokeResults = [
  _SmokeResult(200, 45,  true),
  _SmokeResult(200, 182, true),
  _SmokeResult(200, 78,  true),
  _SmokeResult(200, 91,  true),
  _SmokeResult(200, 67,  true),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day146AwsUrlScreen extends ConsumerWidget {
  const Day146AwsUrlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 146 · Switch to AWS'),
        elevation: 0,
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
            if (tab == 0) const _SwitchTab(),
            if (tab == 1) const _VerifyTab(),
            if (tab == 2) const _SmokeTab(),
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
          colors: [Color(0xFF060E1A), Color(0xFF03070D), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 146', const Color(0xFFF97316)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('AWS Phase · Day 6/10', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Switch API\nto AWS',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'One constant change makes all 75+ API endpoints switch '
            'to the new AWS backend. No UI changes, no feature changes — '
            'seamless to the user.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          // URL comparison
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.remove_circle_outline_rounded,
                      color: Color(0xFFEF4444), size: 13),
                  const SizedBox(width: 6),
                  const Text(
                    'api.zapsafe.app  (DigitalOcean)',
                    style: TextStyle(
                        color: Color(0xFFFF7B72),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFFEF4444)),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.add_circle_outline_rounded,
                      color: Color(0xFF10B981), size: 13),
                  const SizedBox(width: 6),
                  const Text(
                    'api-aws.zapsafe.app  (AWS ap-south-1)',
                    style: TextStyle(
                        color: Color(0xFF7EE787),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('1',    'File changed',   Color(0xFF10B981)),
            _HStat('75+',  'Endpoints auto', Color(0xFF3B82F6)),
            _HStat('0',    'UI changes',     Color(0xFF9CA3AF)),
            _HStat('< 5m', 'Total time',     Color(0xFFF59E0B)),
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
                  color: color, fontSize: 15, fontWeight: FontWeight.w800),
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
      (Icons.edit_rounded,         Color(0xFFF97316), 'Switch URL'),
      (Icons.verified_rounded,     Color(0xFF3B82F6), 'Verify'),
      (Icons.science_rounded,      Color(0xFF10B981), 'Smoke Test'),
    ];
    return Row(
      children: List.generate(3, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Switch URL Tab ─────────────────────────────────────────────────────────────
class _SwitchTab extends ConsumerWidget {
  const _SwitchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approach    = ref.watch(_approachProvider);
    final switchState = ref.watch(_switchStateProvider);
    final isDone      = switchState == _SwitchState.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Architecture context
        const _SectionLabel('AWS ARCHITECTURE  ·  WHAT CHANGED'),
        const SizedBox(height: ZapSpacing.md),
        const _AwsArchCard(),
        const SizedBox(height: ZapSpacing.xl),

        // Approach selector
        const _SectionLabel('SELECT APPROACH'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: isDone ? null : () =>
                  ref.read(_approachProvider.notifier).state = _Approach.dartDefine,
              child: _approachCard(
                title: '--dart-define',
                subtitle: 'Recommended · No code change',
                desc: 'Pass the URL as a build-time constant. '
                    'Switch environments without touching source code.',
                color: const Color(0xFF10B981),
                icon: Icons.terminal_rounded,
                selected: approach == _Approach.dartDefine,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: isDone ? null : () =>
                  ref.read(_approachProvider.notifier).state = _Approach.hardCode,
              child: _approachCard(
                title: 'api_config.dart',
                subtitle: 'Simple · Rebuild needed',
                desc: 'Edit the constant directly. '
                    'Requires a new build to switch back.',
                color: const Color(0xFF3B82F6),
                icon: Icons.code_rounded,
                selected: approach == _Approach.hardCode,
              ),
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // Code change
        const _SectionLabel('THE CHANGE'),
        const SizedBox(height: ZapSpacing.md),
        if (approach == _Approach.dartDefine)
          _codeNote('api_config.dart  +  build command',
              '// api_config.dart — reads from --dart-define\n'
              'class ApiConfig {\n'
              '  static const baseUrl = String.fromEnvironment(\n'
              '    \'API_BASE_URL\',\n'
              '    defaultValue: \'https://api.zapsafe.app\',\n'
              '  );\n'
              '}\n'
              '\n'
              '# Build with AWS URL:\n'
              'flutter build apk --release \\\n'
              '  --dart-define=API_BASE_URL=https://api-aws.zapsafe.app\n'
              '\n'
              '# No code change needed to switch back to DigitalOcean!')
        else
          _codeNote('lib/core/constants/api_config.dart',
              'class ApiConfig {\n'
              '  // ❌ Before\n'
              '  // static const baseUrl = \'https://api.zapsafe.app\';\n'
              '\n'
              '  // ✅ After\n'
              '  static const baseUrl =\n'
              '      \'https://api-aws.zapsafe.app\';\n'
              '\n'
              '  static const timeout  = Duration(seconds: 30);\n'
              '  static const retries  = 3;\n'
              '}'),
        const SizedBox(height: ZapSpacing.lg),

        // Apply button
        if (!isDone)
          _actionButton(
            label: approach == _Approach.dartDefine
                ? 'Apply --dart-define configuration'
                : 'Apply api_config.dart change',
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFFF97316),
            onTap: () async {
              ref.read(_switchStateProvider.notifier).state = _SwitchState.switching;
              await Future.delayed(const Duration(milliseconds: 800));
              if (!context.mounted) return;
              ref.read(_switchStateProvider.notifier).state = _SwitchState.done;
            },
          )
        else
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              'API URL switched to api-aws.zapsafe.app ✅'),

        if (isDone) ...[
          const SizedBox(height: ZapSpacing.md),
          _infoBox(
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF3B82F6),
            text: 'The change is invisible to users — same UI, same features, '
                'different server. Move to Verify tab to confirm all '
                'requests go to AWS.',
          ),
        ],
      ],
    );
  }

  Widget _approachCard({
    required String title,
    required String subtitle,
    required String desc,
    required Color color,
    required IconData icon,
    required bool selected,
  }) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: selected ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: selected ? color : const Color(0xFF4B5563), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF9CA3AF),
                      fontSize: 12, fontWeight: FontWeight.w700,
                      fontFamily: 'monospace')),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 14),
          ]),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: color.withOpacity(0.7), fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
        ]),
      );
}

class _AwsArchCard extends StatelessWidget {
  const _AwsArchCard();

  static const _components = [
    (Icons.phone_android_rounded, Color(0xFF3B82F6),
        'Flutter app', 'api-aws.zapsafe.app'),
    (Icons.arrow_forward_rounded, Color(0xFF4B5563), '', ''),
    (Icons.shield_rounded, Color(0xFFF59E0B),
        'AWS ALB', 'Load Balancer'),
    (Icons.arrow_forward_rounded, Color(0xFF4B5563), '', ''),
    (Icons.view_in_ar_rounded, Color(0xFF8B5CF6),
        'EKS', 'Django pods'),
    (Icons.arrow_forward_rounded, Color(0xFF4B5563), '', ''),
    (Icons.storage_rounded, Color(0xFF10B981),
        'RDS + Cache', 'PostgreSQL + Redis'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        const Text('AWS ap-south-1 (Mumbai)',
            style: TextStyle(
                color: Color(0xFFF97316),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _components.map((c) {
              final (icon, color, title, sub) = c;
              if (title.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(icon, color: color, size: 16),
                );
              }
              return Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Column(children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 4),
                  Text(title,
                      style: TextStyle(
                          color: color, fontSize: 9,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                  Text(sub,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 7),
                      textAlign: TextAlign.center),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Verify Tab ─────────────────────────────────────────────────────────────────
class _VerifyTab extends ConsumerWidget {
  const _VerifyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verState = ref.watch(_verifyStateProvider);
    final switched = ref.watch(_switchStateProvider) == _SwitchState.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Confirm the change actually worked by checking the network log. '
              'Every request must show api-aws.zapsafe.app — '
              'no lingering calls to the old domain.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // How to check
        const _SectionLabel('HOW TO VERIFY  ·  CHARLES PROXY / LOGCAT'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('terminal',
            '# Option A: Android Logcat filter\n'
            'adb logcat -s OkHttp | grep "GET\\|POST\\|PUT"\n'
            '\n'
            '# Option B: Charles Proxy (macOS)\n'
            '# Set proxy on device → open app → check SSL proxied requests\n'
            '\n'
            '# Option C: Flutter network inspector\n'
            '# DevTools → Network → filter by "api-aws"'),
        const SizedBox(height: ZapSpacing.lg),

        // Run verification
        const _SectionLabel('SIMULATED NETWORK LOG'),
        const SizedBox(height: ZapSpacing.md),

        if (!switched)
          _infoBox(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            text: 'Apply the URL switch on the "Switch URL" tab first.',
          )
        else if (verState == _VerifyState.idle)
          _actionButton(
            label: 'Start app and capture network log',
            icon: Icons.network_check_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              ref.read(_verifyStateProvider.notifier).state = _VerifyState.verifying;
              await Future.delayed(const Duration(milliseconds: 1400));
              if (!context.mounted) return;
              ref.read(_verifyStateProvider.notifier).state = _VerifyState.done;
            },
          )
        else if (verState == _VerifyState.verifying)
          _statusChip(Icons.radar_rounded, const Color(0xFF3B82F6),
              'Capturing network requests…', loading: true)
        else ...[
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(children: [
              ..._kNetworkLog.map((line) {
                final isOk    = line.contains('200');
                final isCheck = line.contains('✅');
                final color   = isCheck
                    ? const Color(0xFF10B981)
                    : isOk
                        ? const Color(0xFF7EE787)
                        : const Color(0xFFE6EDF3);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(line,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: isCheck
                              ? FontWeight.w700
                              : FontWeight.w400)),
                );
              }),
            ]),
          ),
          const SizedBox(height: ZapSpacing.md),
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              'All requests → api-aws.zapsafe.app ✅  No old domain calls'),
        ],

        if (verState == _VerifyState.done) ...[
          const SizedBox(height: ZapSpacing.lg),
          const _SectionLabel('CHECKLIST  ·  NO DOMAIN REGRESSIONS'),
          const SizedBox(height: ZapSpacing.md),
          _VerifyChecklist(),
        ],
      ],
    );
  }
}

class _VerifyChecklist extends StatefulWidget {
  @override
  State<_VerifyChecklist> createState() => _VerifyChecklistState();
}

class _VerifyChecklistState extends State<_VerifyChecklist> {
  final _items = [
    (false, 'All API calls show api-aws.zapsafe.app in log'),
    (false, 'Zero requests to api.zapsafe.app (old domain)'),
    (false, 'WebSocket connects to wss://api-aws.zapsafe.app/ws/'),
    (false, 'Firebase URLs unchanged (FCM, Crashlytics)'),
    (false, 'S3 evidence upload endpoint unchanged (direct S3)'),
  ];

  @override
  Widget build(BuildContext context) {
    final doneCount = _items.where((i) => i.$1).length;
    final items     = List<(bool, String)>.from(_items);

    return Container(
      decoration: BoxDecoration(
        color: doneCount == items.length
            ? const Color(0xFF10B981).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: doneCount == items.length
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$doneCount / ${items.length} confirmed',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(
                doneCount == items.length
                    ? '✅ Domain switch confirmed'
                    : 'Tap to confirm',
                style: TextStyle(
                    color: doneCount == items.length
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                    fontSize: 11),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ...items.asMap().entries.map((e) {
          final i    = e.key;
          final (done, label) = e.value;
          final isLast = i == items.length - 1;
          return GestureDetector(
            onTap: () => setState(() => _items[i] = (!done, label)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 11),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: done
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4B5563)),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF10B981), size: 14)
                        : null,
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                          color: done
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                          fontSize: 12,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: const Color(0xFF6B7280),
                        )),
                  ),
                ]),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Smoke Test Tab ─────────────────────────────────────────────────────────────
class _SmokeTab extends ConsumerWidget {
  const _SmokeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results  = ref.watch(_smokeProvider);
    final switched = ref.watch(_switchStateProvider) == _SwitchState.done;
    final allDone  = results.every((r) => r != null);
    final allPass  = results.every((r) => r?.pass == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.science_rounded,
          color: const Color(0xFF10B981),
          text: '5 endpoints cover the core flows: health, auth, profile, '
              'contacts, gamification. All must return 200 with < 500ms '
              'latency from the AWS ap-south-1 region.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (!switched)
          _infoBox(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            text: 'Apply the URL switch first (Switch URL tab).',
          )
        else ...[
          // Run all button
          if (!allDone)
            _actionButton(
              label: 'Run all 5 smoke tests',
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFF10B981),
              onTap: () async {
                for (int i = 0; i < _kSmokeTests.length; i++) {
                  await Future.delayed(
                      Duration(milliseconds: _kSmokeResults[i].latencyMs ~/ 2 + 100));
                  if (!context.mounted) return;
                  final updated = List<_SmokeResult?>.from(
                      ref.read(_smokeProvider));
                  updated[i] = _kSmokeResults[i];
                  ref.read(_smokeProvider.notifier).state = updated;
                }
              },
            ),

          const SizedBox(height: ZapSpacing.md),

          // Endpoint rows
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: _kSmokeTests.asMap().entries.map((e) {
                final i       = e.key;
                final test    = e.value;
                final result  = results[i];
                final isLast  = i == _kSmokeTests.length - 1;

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(children: [
                      // Method badge
                      Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 3),
                        decoration: BoxDecoration(
                          color: test.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(test.method,
                            style: TextStyle(
                                color: test.color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(test.endpoint,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11,
                                    fontFamily: 'monospace')),
                            Text(test.description,
                                style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      // Result
                      if (result == null && results.any((r) => r != null))
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Color(0xFF3B82F6), strokeWidth: 2),
                        )
                      else if (result != null)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${result.statusCode}',
                              style: TextStyle(
                                  color: result.pass
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          Text('${result.latencyMs}ms',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 9,
                                  fontFamily: 'monospace')),
                        ])
                      else
                        GestureDetector(
                          onTap: () async {
                            final updated = List<_SmokeResult?>.from(
                                ref.read(_smokeProvider));
                            updated[i] = null;
                            ref.read(_smokeProvider.notifier).state = updated;
                            await Future.delayed(Duration(
                                milliseconds: _kSmokeResults[i].latencyMs ~/ 2 + 50));
                            if (!context.mounted) return;
                            final done = List<_SmokeResult?>.from(
                                ref.read(_smokeProvider));
                            done[i] = _kSmokeResults[i];
                            ref.read(_smokeProvider.notifier).state = done;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: test.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: test.color.withOpacity(0.35)),
                            ),
                            child: Text('Run',
                                style: TextStyle(
                                    color: test.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]);
              }).toList(),
            ),
          ),

          // Overall result
          if (allDone) ...[
            const SizedBox(height: ZapSpacing.lg),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              decoration: BoxDecoration(
                color: allPass
                    ? const Color(0xFF10B981).withOpacity(0.08)
                    : const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radius),
                border: Border.all(
                  color: allPass
                      ? const Color(0xFF10B981).withOpacity(0.4)
                      : const Color(0xFFEF4444).withOpacity(0.4),
                ),
              ),
              child: Column(children: [
                Icon(
                  allPass ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: allPass
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 40),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  allPass
                      ? 'All 5 smoke tests passed ✅'
                      : 'Some tests failed — check AWS logs',
                  style: TextStyle(
                      color: allPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                if (allPass) ...[
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    'Avg latency: ${(_kSmokeResults.fold(0, (s, r) => s + r.latencyMs) / _kSmokeResults.length).round()} ms  '
                    '·  Region: ap-south-1 (Mumbai)',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                  const SizedBox(height: ZapSpacing.lg),
                  _infoBox(
                    icon: Icons.arrow_forward_rounded,
                    color: const Color(0xFF3B82F6),
                    text: 'Day 147: Test ALL 58 screens against AWS. '
                        'Smoke tests confirm the backend is alive — '
                        'full regression comes next.',
                  ),
                ],
              ]),
            ),
          ],
        ],
      ],
    );
  }
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
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label, {bool loading = false}) =>
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
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
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
              color: const Color(0xFF1C2128), borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF), fontSize: 10, fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3), fontSize: 11, fontFamily: 'monospace', height: 1.6)),
      ]),
    );
