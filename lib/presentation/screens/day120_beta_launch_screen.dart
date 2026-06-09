/// Day 120 — Beta Launch to 1,000 Users
///
/// The culmination of Days 111-119: distribute ZapSafe Beta to 1,000
/// real testers. Covers:
///   • Pre-launch readiness checklist (all Days 111-119 items)
///   • 4 recruitment channels (TestFlight / Play / Telegram / Product Hunt)
///   • Simulated "Launch" countdown flow
///   • Live beta metrics dashboard (testers, crashes, feedback, FP rate)
///   • Daily monitoring plan
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _launchStateProvider   = StateProvider<_LaunchState>((ref) => _LaunchState.prelaunch);
final _checklistProvider     = StateProvider<List<bool>>(
  (ref) => List.filled(_kReadinessItems.length, false),
);
final _selectedChannelProvider = StateProvider<int?>((ref) => null);
final _metricsAnimProvider   = StateProvider<bool>((ref) => false);

enum _LaunchState { prelaunch, launching, live }

// ── Data ───────────────────────────────────────────────────────────────────────
class _ReadinessItem {
  final String label;
  final String day;
  final Color color;
  const _ReadinessItem(this.label, this.day, this.color);
}

const _kReadinessItems = [
  _ReadinessItem('Beta flavor APK (separate icon + package)',           'Day 111', Color(0xFFF97316)),
  _ReadinessItem('Beta onboarding screen with tester responsibilities', 'Day 112', Color(0xFFF97316)),
  _ReadinessItem('In-app feedback FAB visible on all screens',          'Day 113', Color(0xFFF97316)),
  _ReadinessItem('Full feedback form (rating + category + text)',       'Day 114', Color(0xFF3B82F6)),
  _ReadinessItem('False positive report flow for ML training',          'Day 115', Color(0xFFF59E0B)),
  _ReadinessItem('Sentry crash reporting active (DSN configured)',      'Day 116', Color(0xFF8B5CF6)),
  _ReadinessItem('iOS TestFlight build uploaded & approved',            'Day 117', Color(0xFF3B82F6)),
  _ReadinessItem('Android Play Console internal testing live',          'Day 118', Color(0xFF3DDC84)),
  _ReadinessItem('Release notes written (v0.5-beta changelog)',         'Day 119', Color(0xFF10B981)),
  _ReadinessItem('Support email: zapsafe-beta@googlegroups.com',       'Comms',   Color(0xFF9CA3AF)),
];

class _Channel {
  final IconData icon;
  final Color color;
  final String name;
  final String desc;
  final String target;
  final String effort;
  final List<String> steps;
  const _Channel({
    required this.icon,
    required this.color,
    required this.name,
    required this.desc,
    required this.target,
    required this.effort,
    required this.steps,
  });
}

const _kChannels = [
  _Channel(
    icon: Icons.apple_rounded,
    color: Color(0xFF3B82F6),
    name: 'TestFlight + Play Store',
    desc: 'Primary distribution — auto-updates, metrics tracking, Play Store install.',
    target: '700 testers',
    effort: 'Low',
    steps: [
      'Share TestFlight link: testflight.apple.com/join/zApSaFe',
      'Share Play link: play.google.com/apps/testing/com.zapsafe.beta',
      'Post in safety / women\'s communities on Reddit',
      'Send to friends, family, early sign-ups',
    ],
  ),
  _Channel(
    icon: Icons.telegram_rounded,
    color: Color(0xFF2AABEE),
    name: 'Telegram Community',
    desc: 'High-engagement testers — real-time feedback, direct communication.',
    target: '150 testers',
    effort: 'Medium',
    steps: [
      'Create channel: @ZapSafeBeta',
      'Pin TestFlight + APK links',
      'Post in safety / security Telegram groups',
      'Answer questions in real-time',
    ],
  ),
  _Channel(
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFFEF4444),
    name: 'Product Hunt',
    desc: 'Broad reach — 500-1000 beta users instantly from tech-savvy audience.',
    target: '100 testers',
    effort: 'Medium',
    steps: [
      'Post on producthunt.com as "Beta" product',
      'Write compelling tagline: "AI safety app protecting 1M+ users"',
      'Schedule post for Tuesday 12:01 AM PST (peak traffic)',
      'Respond to every comment within 2 hours',
    ],
  ),
  _Channel(
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF97316),
    name: 'Firebase Distribution',
    desc: 'Precise email-based invite — direct to specific tester groups.',
    target: '50 testers',
    effort: 'Low',
    steps: [
      'Add 50 email addresses in Firebase Console',
      'Firebase sends invite email automatically',
      'Testers click link → install app',
      'Use for close contacts / developer team',
    ],
  ),
];

class _Metric {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;
  final bool isGood;
  const _Metric(this.label, this.value, this.sub, this.color, this.icon, this.isGood);
}

const _kMetrics = [
  _Metric('Active Testers',    '847',   'of 1,000 enrolled',  Color(0xFF10B981), Icons.people_rounded,          true),
  _Metric('Crash Rate',        '0.31%', 'target: < 0.5%',     Color(0xFF10B981), Icons.bug_report_rounded,       true),
  _Metric('Feedback Submitted','312',   '4.2 avg rating',     Color(0xFF3B82F6), Icons.rate_review_rounded,      true),
  _Metric('False Positives',   '7.8%',  'target: < 10%',      Color(0xFF10B981), Icons.warning_amber_rounded,    true),
  _Metric('SOS Success Rate',  '99.9%', 'all triggers work',  Color(0xFF10B981), Icons.emergency_rounded,        true),
  _Metric('Avg Session',       '8.4m',  'healthy engagement', Color(0xFF8B5CF6), Icons.timer_rounded,            true),
];

const _kMonitoringItems = [
  (Icons.bug_report_rounded,    Color(0xFFEF4444), 'Check Sentry dashboard',         'Morning — sort by frequency, fix any new P0s same day'),
  (Icons.rate_review_rounded,   Color(0xFF3B82F6), 'Read feedback submissions',      'Morning — read all overnight feedback, tag P0/P1/P2'),
  (Icons.warning_amber_rounded, Color(0xFFF59E0B), 'Review false positive reports',  'Afternoon — are any detection models over-triggering?'),
  (Icons.trending_up_rounded,   Color(0xFF10B981), 'Check retention metrics',        'Afternoon — did users who installed yesterday return?'),
  (Icons.system_update_rounded, Color(0xFF8B5CF6), 'Release hotfix if needed',       'Evening — bundle top 3 bugs → new build → re-distribute'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day120BetaLaunchScreen extends ConsumerWidget {
  const Day120BetaLaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchState = ref.watch(_launchStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 120 · Beta Launch'),
        elevation: 0,
        actions: [
          if (launchState == _LaunchState.live)
            TextButton(
              onPressed: () {
                ref.read(_launchStateProvider.notifier).state =
                    _LaunchState.prelaunch;
                ref.read(_metricsAnimProvider.notifier).state = false;
              },
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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

            // Readiness checklist
            const _SectionLabel('PRE-LAUNCH READINESS  ·  DAYS 111-119'),
            const SizedBox(height: ZapSpacing.md),
            const _ReadinessChecklist(),
            const SizedBox(height: ZapSpacing.xl),

            // Launch button / state
            const _SectionLabel('LAUNCH CONTROL'),
            const SizedBox(height: ZapSpacing.md),
            const _LaunchControl(),
            const SizedBox(height: ZapSpacing.xl),

            // Recruitment channels
            const _SectionLabel('RECRUITMENT CHANNELS'),
            const SizedBox(height: ZapSpacing.md),
            const _ChannelCards(),
            const SizedBox(height: ZapSpacing.xl),

            // Live metrics (shown after launch)
            if (launchState == _LaunchState.live) ...[
              const _SectionLabel('LIVE BETA METRICS  ·  DAY 1'),
              const SizedBox(height: ZapSpacing.md),
              const _MetricsDashboard(),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // Tester target breakdown
            const _SectionLabel('1,000 TESTER TARGET BREAKDOWN'),
            const SizedBox(height: ZapSpacing.md),
            const _TesterBreakdown(),
            const SizedBox(height: ZapSpacing.xl),

            // Daily monitoring
            const _SectionLabel('DAILY MONITORING PLAN'),
            const SizedBox(height: ZapSpacing.md),
            const _MonitoringPlan(),
            const SizedBox(height: ZapSpacing.xl),

            // Phase summary
            const _SectionLabel('BETA PHASE COMPLETE  ·  DAYS 111-120'),
            const SizedBox(height: ZapSpacing.md),
            const _PhaseSummary(),
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
          colors: [Color(0xFF1A0533), Color(0xFF0D0219), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('⚡  BETA  ·  DAY 120', const Color(0xFF8B5CF6)),
              const SizedBox(width: ZapSpacing.sm),
              _badge('🚀  LAUNCH DAY', const Color(0xFFF97316)),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Beta Launch\nto 1,000 Users',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'The culmination of Days 111–119. All beta infrastructure is '
            'in place. Distribute ZapSafe to 1,000 real testers across '
            '4 channels. Collect feedback, fix crashes, improve the model.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('1,000',  'Testers',      Color(0xFF8B5CF6)),
              _HeroStat('4',      'Channels',     Color(0xFFF97316)),
              _HeroStat('30',     'Days beta',    Color(0xFF3B82F6)),
              _HeroStat('Days\n111-120', 'Covered', Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ));
}

// ── Readiness checklist ────────────────────────────────────────────────────────
class _ReadinessChecklist extends ConsumerWidget {
  const _ReadinessChecklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_checklistProvider);
    final doneCount = checks.where((c) => c).length;
    final allDone   = doneCount == _kReadinessItems.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: allDone
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        children: [
          // Progress header
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$doneCount / ${_kReadinessItems.length} ready',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        allDone ? '🚀 Ready to launch!' : 'Tap to check off',
                        key: ValueKey(allDone),
                        style: TextStyle(
                          color: allDone
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: allDone ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: doneCount / _kReadinessItems.length,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(
                      allDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF8B5CF6),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Items
          ...List.generate(_kReadinessItems.length, (i) {
            final item   = _kReadinessItems[i];
            final done   = checks[i];
            final isLast = i == _kReadinessItems.length - 1;

            return GestureDetector(
              onTap: () {
                final updated = List<bool>.from(checks);
                updated[i] = !updated[i];
                ref.read(_checklistProvider.notifier).state = updated;
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md, vertical: 12),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: done
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                          child: done
                              ? const Icon(Icons.check_rounded,
                                  color: Color(0xFF10B981), size: 14)
                              : null,
                        ),
                        const SizedBox(width: ZapSpacing.md),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: done
                                  ? const Color(0xFF6B7280)
                                  : Colors.white,
                              fontSize: 13,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                              decorationColor: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(item.day,
                              style: TextStyle(
                                  color: item.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Launch control ─────────────────────────────────────────────────────────────
class _LaunchControl extends ConsumerWidget {
  const _LaunchControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launchState = ref.watch(_launchStateProvider);
    final checks      = ref.watch(_checklistProvider);
    final allReady    = checks.every((c) => c);

    if (launchState == _LaunchState.live) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF10B981).withOpacity(0.05),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: const Column(
          children: [
            Icon(Icons.rocket_launch_rounded,
                color: Color(0xFF10B981), size: 52),
            SizedBox(height: ZapSpacing.md),
            Text('ZapSafe Beta is LIVE! 🚀',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            SizedBox(height: ZapSpacing.sm),
            Text(
              '1,000 testers invited across 4 channels.\n'
              'Sentry monitoring active. Feedback flowing in.',
              style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (launchState == _LaunchState.launching) {
      return const _LaunchingAnimation();
    }

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          if (!allReady)
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              margin: const EdgeInsets.only(bottom: ZapSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      'Complete all readiness items above before launching.',
                      style: TextStyle(
                          color: Color(0xFFF59E0B), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: allReady
                ? () async {
                    ref.read(_launchStateProvider.notifier).state =
                        _LaunchState.launching;
                    await Future.delayed(
                        const Duration(milliseconds: 2800));
                    if (context.mounted) {
                      ref.read(_launchStateProvider.notifier).state =
                          _LaunchState.live;
                      ref
                          .read(_metricsAnimProvider.notifier)
                          .state = true;
                    }
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: allReady
                    ? const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)])
                    : null,
                color: allReady ? null : const Color(0xFF111111),
                borderRadius: BorderRadius.circular(ZapSpacing.radius),
                boxShadow: allReady
                    ? [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        )
                      ]
                    : null,
                border: allReady
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: allReady
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 22),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    allReady
                        ? 'Launch Beta to 1,000 Testers'
                        : 'Complete checklist to unlock launch',
                    style: TextStyle(
                      color: allReady
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Launching animation ────────────────────────────────────────────────────────
class _LaunchingAnimation extends StatefulWidget {
  const _LaunchingAnimation();

  @override
  State<_LaunchingAnimation> createState() => _LaunchingAnimationState();
}

class _LaunchingAnimationState extends State<_LaunchingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  int _step = 0;

  static const _steps = [
    'Distributing TestFlight links…',
    'Activating Play Console internal track…',
    'Posting to Telegram @ZapSafeBeta…',
    'Inviting via Firebase Distribution…',
    '🚀 1,000 testers invited!',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _runSteps();
  }

  Future<void> _runSteps() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 550));
      if (mounted) setState(() => _step = i);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0533),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: const Icon(Icons.rocket_launch_rounded,
                color: Color(0xFF8B5CF6), size: 52),
          ),
          const SizedBox(height: ZapSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _steps[_step],
              key: ValueKey(_step),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          LinearProgressIndicator(
            value: (_step + 1) / _steps.length,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor:
                const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
}

// ── Channel cards ──────────────────────────────────────────────────────────────
class _ChannelCards extends ConsumerWidget {
  const _ChannelCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedChannelProvider);

    return Column(
      children: _kChannels.asMap().entries.map((e) {
        final i       = e.key;
        final channel = e.value;
        final isOpen  = selected == i;

        return GestureDetector(
          onTap: () => ref.read(_selectedChannelProvider.notifier).state =
              isOpen ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: isOpen
                  ? channel.color.withOpacity(0.08)
                  : const Color(0xFF1A1A1A),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: isOpen
                    ? channel.color.withOpacity(0.5)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: channel.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(channel.icon,
                            color: channel.color, size: 22),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(channel.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text(channel.desc,
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                    height: 1.4),
                                maxLines: isOpen ? 10 : 1,
                                overflow: isOpen
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(channel.target,
                              style: TextStyle(
                                  color: channel.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(channel.effort,
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 9)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Steps (expanded)
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: isOpen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(
                                height: 1, color: Color(0xFF2A2A2A)),
                            Padding(
                              padding: const EdgeInsets.all(ZapSpacing.md),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: channel.steps
                                    .asMap()
                                    .entries
                                    .map((se) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: ZapSpacing.sm),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: channel.color
                                                      .withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${se.key + 1}',
                                                    style: TextStyle(
                                                      color: channel.color,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: ZapSpacing.sm),
                                              Expanded(
                                                child: Text(se.value,
                                                    style: const TextStyle(
                                                      color:
                                                          Color(0xFFD1D5DB),
                                                      fontSize: 12,
                                                      height: 1.4,
                                                    )),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Metrics dashboard ──────────────────────────────────────────────────────────
class _MetricsDashboard extends StatelessWidget {
  const _MetricsDashboard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 2-column grid
        Row(
          children: [
            Expanded(child: _MetricCard(metric: _kMetrics[0])),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: _MetricCard(metric: _kMetrics[1])),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            Expanded(child: _MetricCard(metric: _kMetrics[2])),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: _MetricCard(metric: _kMetrics[3])),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            Expanded(child: _MetricCard(metric: _kMetrics[4])),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: _MetricCard(metric: _kMetrics[5])),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: metric.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: metric.color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: metric.color, size: 16),
              const Spacer(),
              Icon(
                metric.isGood
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                color: metric.isGood
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(metric.value,
              style: TextStyle(
                  color: metric.color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(metric.label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(metric.sub,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Tester breakdown ───────────────────────────────────────────────────────────
class _TesterBreakdown extends StatelessWidget {
  const _TesterBreakdown();

  @override
  Widget build(BuildContext context) {
    const channels = [
      ('TestFlight + Play', 700, Color(0xFF3B82F6)),
      ('Telegram',          150, Color(0xFF2AABEE)),
      ('Product Hunt',      100, Color(0xFFEF4444)),
      ('Firebase Dist.',     50, Color(0xFFF97316)),
    ];
    const total = 1000.0;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: channels.map((ch) {
                final (_, count, color) = ch;
                return Expanded(
                  flex: count,
                  child: Container(height: 16, color: color),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          // Legend
          ...channels.map((ch) {
            final (name, count, color) = ch;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            color: Color(0xFFD1D5DB), fontSize: 13)),
                  ),
                  Text('$count',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: ZapSpacing.sm),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(count / total * 100).round()}%',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const Text('1,000',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Daily monitoring ───────────────────────────────────────────────────────────
class _MonitoringPlan extends StatelessWidget {
  const _MonitoringPlan();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _kMonitoringItems.asMap().entries.map((e) {
          final i = e.key;
          final (icon, color, title, desc) = e.value;
          final isLast = i == _kMonitoringItems.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(desc,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Phase summary ──────────────────────────────────────────────────────────────
class _PhaseSummary extends StatelessWidget {
  const _PhaseSummary();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Day 111', 'Beta Flavor APK',         Color(0xFFF97316), Icons.science_rounded),
      ('Day 112', 'Beta Onboarding',          Color(0xFFF97316), Icons.waving_hand_rounded),
      ('Day 113', 'Feedback FAB',             Color(0xFFF97316), Icons.feedback_rounded),
      ('Day 114', 'Feedback Form',            Color(0xFF3B82F6), Icons.rate_review_rounded),
      ('Day 115', 'False Positive Flow',      Color(0xFFF59E0B), Icons.warning_amber_rounded),
      ('Day 116', 'Sentry Crash Reporting',   Color(0xFF8B5CF6), Icons.bug_report_rounded),
      ('Day 117', 'iOS TestFlight',           Color(0xFF3B82F6), Icons.apple_rounded),
      ('Day 118', 'Android Distribution',     Color(0xFF3DDC84), Icons.android_rounded),
      ('Day 119', 'Release Notes',            Color(0xFF10B981), Icons.new_releases_rounded),
      ('Day 120', 'Beta Launch 🚀',           Color(0xFF8B5CF6), Icons.rocket_launch_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ZapSpacing.radius - 1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 18),
                SizedBox(width: ZapSpacing.sm),
                Text('Beta Infrastructure Phase Complete',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              children: items.map((item) {
                final (day, label, color, icon) = item;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 13),
                      const SizedBox(width: 5),
                      Text(day,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text(label,
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF8B5CF6), size: 16),
                const SizedBox(width: ZapSpacing.sm),
                const Expanded(
                  child: Text(
                    'Next: Days 121-140 — Feedback Analysis & Iteration',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
