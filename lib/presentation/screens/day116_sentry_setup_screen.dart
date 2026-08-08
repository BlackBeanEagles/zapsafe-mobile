/// Day 116 — Sentry Crash Reporting Setup
///
/// Demonstrates Sentry integration for ZapSafe beta:
///   • Setup guide (DSN, pubspec, main.dart initialisation)
///   • Mock crash dashboard (frequency-sorted, stack traces, device breakdown)
///   • Simulated "test crash" button
///   • 7-day crash trend bar chart
///   • Priority triage (P0–P3)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _selectedCrashProvider = StateProvider<int?>((ref) => null);
final _testCrashStateProvider = StateProvider<_TestState>((ref) => _TestState.idle);
final _setupStepProvider = StateProvider<int>((ref) => 0);

enum _TestState { idle, throwing, captured, done }

// ── Mock data ──────────────────────────────────────────────────────────────────
class _CrashReport {
  final String title;
  final String file;
  final int affected;
  final int total;
  final String priority;
  final Color priorityColor;
  final String os;
  final String lastSeen;
  final List<String> stackTrace;

  const _CrashReport({
    required this.title,
    required this.file,
    required this.affected,
    required this.total,
    required this.priority,
    required this.priorityColor,
    required this.os,
    required this.lastSeen,
    required this.stackTrace,
  });
}

const _kCrashes = [
  _CrashReport(
    title: 'NullPointerException in SOS send',
    file: 'sos_service.dart:142',
    affected: 47,
    total: 312,
    priority: 'P0',
    priorityColor: Color(0xFFEF4444),
    os: 'Android 11 · Samsung',
    lastSeen: '2 min ago',
    stackTrace: [
      '#0  SosService.sendAlert (sos_service.dart:142)',
      '#1  SosBloc._onTrigger (sos_bloc.dart:88)',
      '#2  _SosActiveScreenState.build (sos_active_screen.dart:34)',
      '#3  StatefulElement.build (framework.dart:5116)',
    ],
  ),
  _CrashReport(
    title: 'OutOfMemoryError in location tracking',
    file: 'gps_service.dart:78',
    affected: 31,
    total: 198,
    priority: 'P0',
    priorityColor: Color(0xFFEF4444),
    os: 'iOS 15 · iPhone 7',
    lastSeen: '18 min ago',
    stackTrace: [
      '#0  GpsService._startTracking (gps_service.dart:78)',
      '#1  BackgroundEngine.init (background_engine.dart:55)',
      '#2  main.<anonymous closure> (main.dart:22)',
    ],
  ),
  _CrashReport(
    title: 'TFLite model inference crash',
    file: 'scream_classifier.dart:201',
    affected: 19,
    total: 87,
    priority: 'P1',
    priorityColor: Color(0xFFF97316),
    os: 'Android 12 · Various',
    lastSeen: '1 hr ago',
    stackTrace: [
      '#0  ScreamClassifier.runInference (scream_classifier.dart:201)',
      '#1  DcsEngine._onAudioChunk (dcs_engine.dart:113)',
      '#2  AudioCaptureService._processBuffer (audio_capture.dart:66)',
    ],
  ),
  _CrashReport(
    title: 'WebSocket disconnect on background',
    file: 'websocket_service.dart:44',
    affected: 8,
    total: 34,
    priority: 'P2',
    priorityColor: Color(0xFFF59E0B),
    os: 'Android 13 · Pixel',
    lastSeen: '3 hr ago',
    stackTrace: [
      '#0  WebSocketService._reconnect (websocket_service.dart:44)',
      '#1  LiveChatScreen._onDisconnect (live_chat_screen.dart:190)',
    ],
  ),
];

// 7-day crash counts (newest last)
const _kTrend = [42, 38, 55, 29, 61, 47, 33];
const _kTrendDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day116SentrySetupScreen extends ConsumerWidget {
  const Day116SentrySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCrash = ref.watch(_selectedCrashProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 116 · Sentry Crash Reporting'),
        elevation: 0,
      ),
      body: selectedCrash != null
          ? _CrashDetailView(
              crash: _kCrashes[selectedCrash],
              onBack: () =>
                  ref.read(_selectedCrashProvider.notifier).state = null,
            )
          : _DashboardView(
              onCrashTap: (i) =>
                  ref.read(_selectedCrashProvider.notifier).state = i,
            ),
    );
  }
}

// ── Dashboard view ─────────────────────────────────────────────────────────────
class _DashboardView extends ConsumerWidget {
  final ValueChanged<int> onCrashTap;
  const _DashboardView({required this.onCrashTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hero(),
          const SizedBox(height: ZapSpacing.xl),

          // Setup guide
          const _SectionLabel('SETUP GUIDE · 5 STEPS'),
          const SizedBox(height: ZapSpacing.md),
          const _SetupGuide(),
          const SizedBox(height: ZapSpacing.xl),

          // Stats row
          const _SectionLabel('BETA CRASH OVERVIEW'),
          const SizedBox(height: ZapSpacing.md),
          const _StatsRow(),
          const SizedBox(height: ZapSpacing.xl),

          // Trend chart
          const _SectionLabel('7-DAY CRASH TREND'),
          const SizedBox(height: ZapSpacing.md),
          const _TrendChart(),
          const SizedBox(height: ZapSpacing.xl),

          // Crash list
          const _SectionLabel('TOP CRASHES  ·  TAP FOR STACK TRACE'),
          const SizedBox(height: ZapSpacing.md),
          ..._kCrashes.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: _CrashTile(
                    crash: e.value,
                    onTap: () => onCrashTap(e.key),
                  ),
                ),
              ),
          const SizedBox(height: ZapSpacing.xl),

          // Test crash button
          const _SectionLabel('TEST CRASH  ·  SIMULATE SENTRY CAPTURE'),
          const SizedBox(height: ZapSpacing.md),
          const _TestCrashCard(),
          const SizedBox(height: ZapSpacing.huge),
        ],
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
          colors: [Color(0xFF2D1B69), Color(0xFF110D2E), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_rounded,
                    color: Color(0xFF8B5CF6), size: 13),
                SizedBox(width: 5),
                Text(
                  '⚡  BETA  ·  DAY 116',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Sentry Crash\nReporting',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Every crash is automatically captured with stack trace, '
            'device info, OS version, and user impact. '
            'Environment: beta · Release: v0.5-beta.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('Auto',    'Capture',       Color(0xFF8B5CF6)),
              _HeroStat('Stack',   'Trace',         Color(0xFFEF4444)),
              _HeroStat('Device',  'Info',          Color(0xFF3B82F6)),
              _HeroStat('P0–P3',   'Priority',      Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ));
  }
}

// ── Setup guide ────────────────────────────────────────────────────────────────
const _kSetupSteps = [
  (
    Icons.account_circle_rounded,
    Color(0xFF3B82F6),
    'Create Sentry account',
    'sentry.io → New Project → Flutter → get your DSN URL',
  ),
  (
    Icons.code_rounded,
    Color(0xFF10B981),
    'Add to pubspec.yaml',
    'sentry_flutter: ^7.0.0',
  ),
  (
    Icons.settings_rounded,
    Color(0xFF8B5CF6),
    'Initialise in main.dart',
    'SentryFlutter.init() wraps runApp() with DSN + environment',
  ),
  (
    Icons.bug_report_rounded,
    Color(0xFFEF4444),
    'Every crash auto-captured',
    'Stack trace · device info · OS version · user ID (hashed)',
  ),
  (
    Icons.dashboard_rounded,
    Color(0xFFF59E0B),
    'Monitor at sentry.io',
    'Sort by frequency · filter by OS · set P0–P3 priority',
  ),
];

class _SetupGuide extends ConsumerWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStep = ref.watch(_setupStepProvider);

    return Column(
      children: [
        // Step list
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children:
                List.generate(_kSetupSteps.length, (i) {
              final (icon, color, title, desc) = _kSetupSteps[i];
              final isActive = i == activeStep;
              final isDone   = i < activeStep;
              final isLast   = i == _kSetupSteps.length - 1;

              return GestureDetector(
                onTap: () => ref
                    .read(_setupStepProvider.notifier)
                    .state = i,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(ZapSpacing.md),
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: i == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(
                                    ZapSpacing.radius - 1))
                            : i == _kSetupSteps.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(
                                        ZapSpacing.radius - 1))
                                : BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          // Step indicator
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981)
                                      .withOpacity(0.15)
                                  : color.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone
                                    ? const Color(0xFF10B981)
                                        .withOpacity(0.4)
                                    : isActive
                                        ? color.withOpacity(0.5)
                                        : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              isDone
                                  ? Icons.check_rounded
                                  : icon,
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: ZapSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : const Color(
                                              0xFFD1D5DB),
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    )),
                                if (isActive) ...[
                                  const SizedBox(height: ZapSpacing.xs),
                                  Text(desc,
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 11,
                                        height: 1.4,
                                      )),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            'Step ${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                          height: 1, color: Color(0xFF2A2A2A)),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        // main.dart code snippet (shown when step 2 is active)
        if (activeStep == 2) const _MainDartSnippet(),
      ],
    );
  }
}

class _MainDartSnippet extends StatelessWidget {
  const _MainDartSnippet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FileChip('main.dart'),
          SizedBox(height: ZapSpacing.md),
          Text(
            'await SentryFlutter.init(\n'
            '  (options) {\n'
            '    options.dsn = \'https://xxx@xxx.ingest.sentry.io/123\';\n'
            '    options.environment = \'beta\';\n'
            '    options.release    = \'v0.5-beta\';\n'
            '    options.tracesSampleRate = 1.0;\n'
            '  },\n'
            '  appRunner: () => runApp(\n'
            '    ProviderScope(child: ZapSafeApp()),\n'
            '  ),\n'
            ');',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StatCard('105',  'Total\nCrashes',  Color(0xFFEF4444), Icons.bug_report_rounded),
        SizedBox(width: ZapSpacing.sm),
        _StatCard('4',    'Unique\nIssues',  Color(0xFFF97316), Icons.category_rounded),
        SizedBox(width: ZapSpacing.sm),
        _StatCard('0.35%','Crash\nRate',     Color(0xFF10B981), Icons.percent_rounded),
        SizedBox(width: ZapSpacing.sm),
        _StatCard('2',    'P0\nIssues',      Color(0xFF8B5CF6), Icons.priority_high_rounded),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCard(this.value, this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: ZapSpacing.md, horizontal: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius:
              BorderRadius.circular(ZapSpacing.radiusSmall),
          border:
              Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 9,
                    height: 1.3),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Trend chart ────────────────────────────────────────────────────────────────
class _TrendChart extends StatelessWidget {
  const _TrendChart();

  @override
  Widget build(BuildContext context) {
    const maxVal = 61.0;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Bars
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_kTrend.length, (i) {
                final frac = _kTrend[i] / maxVal;
                final isToday = i == _kTrend.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${_kTrend[i]}',
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF6B7280),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: Duration(
                              milliseconds: 400 + i * 60),
                          height: 60 * frac,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF8B5CF6)
                                    .withOpacity(0.35),
                            borderRadius:
                                const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          // Day labels
          Row(
            children: List.generate(_kTrend.length, (i) {
              final isToday = i == _kTrend.length - 1;
              return Expanded(
                child: Text(
                  isToday ? 'Today' : _kTrendDays[i],
                  style: TextStyle(
                    color: isToday
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF6B7280),
                    fontSize: 9,
                    fontWeight: isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Crash tile ─────────────────────────────────────────────────────────────────
class _CrashTile extends StatelessWidget {
  final _CrashReport crash;
  final VoidCallback onTap;
  const _CrashTile({required this.crash, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius:
              BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            // Priority badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    crash.priorityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: crash.priorityColor
                        .withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  crash.priority,
                  style: TextStyle(
                    color: crash.priorityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(crash.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(crash.file,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          )),
                      const Spacer(),
                      Text(crash.lastSeen,
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 10,
                          )),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  // Affected bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: crash.affected /
                                crash.total,
                            backgroundColor:
                                const Color(0xFF2A2A2A),
                            valueColor:
                                AlwaysStoppedAnimation(
                                    crash.priorityColor),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        '${crash.affected}/${crash.total} users',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF4B5563), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Test crash card ────────────────────────────────────────────────────────────
class _TestCrashCard extends ConsumerWidget {
  const _TestCrashCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_testCrashStateProvider);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0000),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_rounded,
                  color: Color(0xFFEF4444), size: 18),
              SizedBox(width: ZapSpacing.sm),
              Text(
                'Test Sentry capture',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Throws a test exception → Sentry captures it → '
            'appears in dashboard within seconds.',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          if (state == _TestState.idle)
            _ActionButton(
              label: 'Throw test exception',
              icon: Icons.bolt_rounded,
              color: const Color(0xFFEF4444),
              onTap: () async {
                ref.read(_testCrashStateProvider.notifier).state =
                    _TestState.throwing;
                await Future.delayed(
                    const Duration(milliseconds: 600));
                ref.read(_testCrashStateProvider.notifier).state =
                    _TestState.captured;
                await Future.delayed(
                    const Duration(milliseconds: 800));
                ref.read(_testCrashStateProvider.notifier).state =
                    _TestState.done;
              },
            )
          else if (state == _TestState.throwing)
            const _StatusChip(
              icon: Icons.bolt_rounded,
              color: Color(0xFFEF4444),
              label: 'Throwing exception…',
            )
          else if (state == _TestState.captured)
            const _StatusChip(
              icon: Icons.cloud_upload_rounded,
              color: Color(0xFF8B5CF6),
              label: 'Sentry capturing…',
            )
          else ...[
            const _StatusChip(
              icon: Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              label: 'Captured! Visible in Sentry dashboard.',
            ),
            const SizedBox(height: ZapSpacing.sm),
            GestureDetector(
              onTap: () => ref
                  .read(_testCrashStateProvider.notifier)
                  .state = _TestState.idle,
              child: const Center(
                child: Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius:
              BorderRadius.circular(ZapSpacing.radiusSmall),
          border:
              Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatusChip(
      {required this.icon,
      required this.color,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius:
            BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ── Crash detail view ──────────────────────────────────────────────────────────
class _CrashDetailView extends StatelessWidget {
  final _CrashReport crash;
  final VoidCallback onBack;
  const _CrashDetailView(
      {required this.crash, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back
          GestureDetector(
            onTap: onBack,
            child: const Row(
              children: [
                Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF6B7280), size: 18),
                SizedBox(width: 6),
                Text('Back to dashboard',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // Title + priority
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: crash.priorityColor
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: crash.priorityColor
                          .withOpacity(0.5)),
                ),
                child: Text(crash.priority,
                    style: TextStyle(
                      color: crash.priorityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(crash.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),

          // Meta
          const _SectionLabel('CRASH DETAILS'),
          const SizedBox(height: ZapSpacing.md),
          _DetailRow(Icons.code_rounded,
              const Color(0xFF3B82F6), 'File', crash.file),
          _DetailRow(Icons.smartphone_rounded,
              const Color(0xFF8B5CF6), 'Device', crash.os),
          _DetailRow(Icons.people_rounded,
              const Color(0xFFEF4444), 'Affected',
              '${crash.affected} of ${crash.total} users'),
          _DetailRow(Icons.access_time_rounded,
              const Color(0xFFF59E0B), 'Last seen',
              crash.lastSeen),
          const SizedBox(height: ZapSpacing.xl),

          // Stack trace
          const _SectionLabel('STACK TRACE'),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
              border:
                  Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: crash.stackTrace
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(
                            bottom: 8),
                        child: Text(line,
                            style: const TextStyle(
                              color: Color(0xFFE6EDF3),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.5,
                            )),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _DetailRow(this.icon, this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text('$label:',
              style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
class _FileChip extends StatelessWidget {
  final String label;
  const _FileChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
            color: Color(0xFF79C0FF),
            fontSize: 10,
            fontFamily: 'monospace',
          )),
    );
  }
}
