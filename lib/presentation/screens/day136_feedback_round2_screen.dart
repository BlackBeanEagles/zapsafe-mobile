/// Day 136 — Second Feedback Round (Part 1)
///
/// Two weeks after releasing v0.5-beta-2, it's time to measure whether
/// the 14 days of fixes (Days 121-134) actually moved the needle.
///
/// Day 136 covers:
///   1. Send targeted survey: "Did the update fix your issues?"
///   2. Pull fresh Sentry metrics — compare to Day 121 baseline
///   3. Feature-by-feature fix verification grid
///   4. Retention heatmap — are testers coming back?
///
/// Day 137: read qualitative feedback, make final iteration decisions,
///          tag v0.5-beta-final if metrics pass.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _surveyStateProvider  = StateProvider<_SurveyState>((ref) => _SurveyState.idle);
final _surveyRatingProvider = StateProvider<int>((ref) => 0);
final _surveyFixedProvider  = StateProvider<List<bool?>>((ref) => List.filled(6, null));
final _sentryPulledProvider = StateProvider<bool>((ref) => false);
final _retentionDayProvider = StateProvider<int>((ref) => 7);

enum _SurveyState { idle, sending, sent }

// ── Data ───────────────────────────────────────────────────────────────────────
class _SentryMetric {
  final String  title;
  final double  before;
  final double  after;
  final String  unit;
  final Color   color;
  final IconData icon;
  final bool    lowerIsBetter;
  const _SentryMetric({
    required this.title,
    required this.before,
    required this.after,
    required this.unit,
    required this.color,
    required this.icon,
    this.lowerIsBetter = true,
  });

  double get improvement =>
      lowerIsBetter ? (before - after) / before : (after - before) / before;
  bool get passed =>
      lowerIsBetter ? after < before : after > before;
}

const _kSentryMetrics = [
  _SentryMetric(
    title: 'Crash rate',
    before: 0.31, after: 0.09,
    unit: '%',
    color: Color(0xFF10B981),
    icon: Icons.bug_report_rounded,
  ),
  _SentryMetric(
    title: 'P0 active issues',
    before: 2, after: 0,
    unit: '',
    color: Color(0xFF10B981),
    icon: Icons.priority_high_rounded,
  ),
  _SentryMetric(
    title: 'OOM events/day',
    before: 18, after: 1,
    unit: '',
    color: Color(0xFF10B981),
    icon: Icons.memory_rounded,
  ),
  _SentryMetric(
    title: 'Notification delay',
    before: 32, after: 1.8,
    unit: 's',
    color: Color(0xFF10B981),
    icon: Icons.notifications_rounded,
  ),
  _SentryMetric(
    title: 'False positive rate',
    before: 7.8, after: 4.6,
    unit: '%',
    color: Color(0xFF10B981),
    icon: Icons.warning_amber_rounded,
  ),
  _SentryMetric(
    title: 'Session duration',
    before: 4.2, after: 8.8,
    unit: ' min',
    color: Color(0xFF10B981),
    icon: Icons.timer_rounded,
    lowerIsBetter: false,
  ),
];

class _FixVerification {
  final String  fix;
  final String  version;
  final Color   color;
  final double  beforeVal;
  final double  afterVal;
  final String  unit;
  final String  evidence;
  const _FixVerification({
    required this.fix,
    required this.version,
    required this.color,
    required this.beforeVal,
    required this.afterVal,
    required this.unit,
    required this.evidence,
  });

  bool get passed => afterVal < beforeVal;
}

const _kFixVerifications = [
  _FixVerification(
    fix: 'Android 11 SMS crash',
    version: 'v0.5.1',
    color: Color(0xFF10B981),
    beforeVal: 51, afterVal: 0,
    unit: ' new events',
    evidence: 'android_11_sms_crash: 0 events in 14-day window',
  ),
  _FixVerification(
    fix: 'iPhone 7 OOM',
    version: 'v0.5.1',
    color: Color(0xFF10B981),
    beforeVal: 32, afterVal: 0,
    unit: ' new events',
    evidence: 'ios_oom_location: 0 events in 14-day window',
  ),
  _FixVerification(
    fix: 'False positive rate',
    version: 'v0.5.2',
    color: Color(0xFF10B981),
    beforeVal: 7.8, afterVal: 4.6,
    unit: '%',
    evidence: 'FP reports: 3 in 14 days (was 78 in first 14 days)',
  ),
  _FixVerification(
    fix: 'Samsung notification delay',
    version: 'v0.5.3',
    color: Color(0xFF10B981),
    beforeVal: 32, afterVal: 1.8,
    unit: 's avg',
    evidence: 'P95 notification latency: 1.8s (Samsung, Android 13)',
  ),
  _FixVerification(
    fix: 'Cold start time',
    version: 'v0.5.4',
    color: Color(0xFF10B981),
    beforeVal: 5.2, afterVal: 1.8,
    unit: 's',
    evidence: 'Trace: Flutter first-frame 1.78s on Pixel 6',
  ),
  _FixVerification(
    fix: 'Onboarding abandon rate',
    version: 'v0.5.6',
    color: Color(0xFF10B981),
    beforeVal: 34.0, afterVal: 9.2,
    unit: '%',
    evidence: '9.2% abandon at new Step 2 (was 34% at old Step 3)',
  ),
];

// Retention data — daily active users % on each day post-install
// Index = day post-install (0-13), value = % still active
const _kRetentionBefore = [
  100.0, 68, 52, 44, 38, 33, 30, 27, 25, 23, 21, 20, 19, 18
];
const _kRetentionAfter = [
  100.0, 78, 65, 58, 52, 48, 45, 43, 41, 39, 38, 37, 36, 35
];

const _kSurveyQuestions = [
  'Were crashes fixed?',
  'Battery life improved?',
  'Notifications faster?',
  'SOS trigger clearer?',
  'Onboarding easier?',
  'Overall improvement?',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day136FeedbackRound2Screen extends ConsumerWidget {
  const Day136FeedbackRound2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 136 · Feedback Round 2'),
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

            if (tab == 0) const _SurveyTab(),
            if (tab == 1) const _SentryTab(),
            if (tab == 2) const _RetentionTab(),
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
          colors: [Color(0xFF0A1520), Color(0xFF050B10), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 136', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('2 weeks post v0.5-beta-2', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Second Feedback\nRound',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'v0.5-beta-2 has been live for 2 weeks. '
            'Now measuring: did the fixes actually land? '
            'Survey testers, pull fresh Sentry data, check retention.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('847',  'Active testers', Color(0xFF3B82F6)),
            _HStat('14d',  'Post-release',   Color(0xFF9CA3AF)),
            _HStat('6',    'Fixes tracked',  Color(0xFF10B981)),
            _HStat('2-way','Survey',         Color(0xFFF59E0B)),
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
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
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
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.poll_rounded,         Color(0xFF3B82F6), 'Survey'),
      (Icons.bug_report_rounded,   Color(0xFFEF4444), 'Sentry'),
      (Icons.people_rounded,       Color(0xFF10B981), 'Retention'),
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
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Survey Tab ─────────────────────────────────────────────────────────────────
class _SurveyTab extends ConsumerWidget {
  const _SurveyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyState = ref.watch(_surveyStateProvider);
    final rating      = ref.watch(_surveyRatingProvider);
    final fixed       = ref.watch(_surveyFixedProvider);
    final allAnswered = fixed.every((v) => v != null) && rating > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.poll_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Targeted follow-up survey sent to 847 testers: '
              '"Did v0.5-beta-2 fix the issues you reported?" '
              'Two-part: yes/no per fix + overall rating.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (surveyState != _SurveyState.sent) ...[
          // Overall rating
          const _SectionLabel('OVERALL IMPROVEMENT RATING'),
          const SizedBox(height: ZapSpacing.md),
          _OverallRating(rating: rating,
              onChanged: (v) =>
                  ref.read(_surveyRatingProvider.notifier).state = v),
          const SizedBox(height: ZapSpacing.xl),

          // Per-fix verification
          const _SectionLabel('WAS THIS FIX EFFECTIVE?  ·  TAP TO ANSWER'),
          const SizedBox(height: ZapSpacing.md),
          ..._kSurveyQuestions.asMap().entries.map((e) {
            final i       = e.key;
            final question= e.value;
            final answer  = fixed[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _SurveyQuestion(
                index: i,
                question: question,
                answer: answer,
                onYes: () {
                  final u = List<bool?>.from(ref.read(_surveyFixedProvider));
                  u[i] = true;
                  ref.read(_surveyFixedProvider.notifier).state = u;
                },
                onNo: () {
                  final u = List<bool?>.from(ref.read(_surveyFixedProvider));
                  u[i] = false;
                  ref.read(_surveyFixedProvider.notifier).state = u;
                },
              ),
            );
          }),
          const SizedBox(height: ZapSpacing.lg),

          // Submit
          if (surveyState == _SurveyState.sending)
            _statusChip(Icons.send_rounded, const Color(0xFF3B82F6),
                'Submitting survey…', loading: true)
          else
            _actionButton(
              label: allAnswered
                  ? 'Submit survey response'
                  : 'Answer all questions above',
              icon: Icons.send_rounded,
              color: allAnswered
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF4B5563),
              onTap: allAnswered
                  ? () async {
                      ref.read(_surveyStateProvider.notifier).state =
                          _SurveyState.sending;
                      await Future.delayed(
                          const Duration(milliseconds: 1000));
                      if (!context.mounted) return;
                      ref.read(_surveyStateProvider.notifier).state =
                          _SurveyState.sent;
                    }
                  : () {},
            ),
        ] else ...[
          // Results view
          const _SurveyResults(),
        ],
      ],
    );
  }
}

class _OverallRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  const _OverallRating({required this.rating, required this.onChanged});

  static const _labels = ['', 'Much worse', 'Slightly worse', 'Same', 'Better', 'Much better!'];
  static const _colors = [
    Colors.transparent,
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
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
        const Text(
          'Compared to before v0.5-beta-2, the app is…',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: List.generate(5, (i) {
            final val       = i + 1;
            final isSelected = val == rating;
            final color     = _colors[val];
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : const Color(0xFF111111),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: isSelected
                          ? color.withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Text('$val',
                        style: TextStyle(
                            color: isSelected ? color : const Color(0xFF4B5563),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            );
          }),
        ),
        if (rating > 0) ...[
          const SizedBox(height: ZapSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _labels[rating],
              key: ValueKey(rating),
              style: TextStyle(
                  color: _colors[rating],
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SurveyQuestion extends StatelessWidget {
  final int index;
  final String question;
  final bool? answer;
  final VoidCallback onYes, onNo;
  const _SurveyQuestion({
    required this.index,
    required this.question,
    required this.answer,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: answer == true
            ? const Color(0xFF10B981).withOpacity(0.07)
            : answer == false
                ? const Color(0xFFEF4444).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: answer == true
              ? const Color(0xFF10B981).withOpacity(0.35)
              : answer == false
                  ? const Color(0xFFEF4444).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Text(question,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13)),
        ),
        const SizedBox(width: ZapSpacing.sm),
        _answerBtn('Yes', answer == true,
            const Color(0xFF10B981), onYes),
        const SizedBox(width: 6),
        _answerBtn('No', answer == false,
            const Color(0xFFEF4444), onNo),
      ]),
    );
  }

  Widget _answerBtn(
          String label, bool selected, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color.withOpacity(0.5) : const Color(0xFF2A2A2A)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? color : const Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400)),
        ),
      );
}

class _SurveyResults extends StatelessWidget {
  const _SurveyResults();

  // Simulated aggregated results from 847 testers
  static const _results = [
    ('Crashes fixed?',         0.94),
    ('Battery improved?',      0.88),
    ('Notifications faster?',  0.91),
    ('SOS trigger clearer?',   0.82),
    ('Onboarding easier?',     0.79),
    ('Overall improvement?',   0.87),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall score
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF10B981).withOpacity(0.12),
              const Color(0xFF10B981).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.sentiment_very_satisfied_rounded,
                color: Color(0xFF10B981), size: 44),
            const SizedBox(width: ZapSpacing.lg),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tester Satisfaction',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                  Text('4.4 / 5',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  Text('avg rating from 612 responses',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statChip('612', 'responded', const Color(0xFF3B82F6)),
                const SizedBox(height: ZapSpacing.xs),
                _statChip('235', 'no response', const Color(0xFF4B5563)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('PER-FIX SATISFACTION  ·  % SAID "YES"'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _results.asMap().entries.map((e) {
              final i = e.key;
              final (question, pct) = e.value;
              final isLast = i == _results.length - 1;
              final col    = pct >= 0.85
                  ? const Color(0xFF10B981)
                  : pct >= 0.70
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFF59E0B);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(question,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                        Text('${(pct * 100).round()}%',
                            style: TextStyle(
                                color: col,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: ZapSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: const Color(0xFF2A2A2A),
                          valueColor: AlwaysStoppedAnimation(col),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Top comment
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: const Column(children: [
            _SectionLabel('TOP COMMENT'),
            SizedBox(height: ZapSpacing.md),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.format_quote_rounded,
                  color: Color(0xFF10B981), size: 18),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  '"The notification fix is huge — used to wait 40 seconds on my Samsung. '
                  'Now it\'s instant. And the app no longer crashes in the background. '
                  'Rating going from 3★ to 5★."',
                  style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 13,
                      height: 1.6,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ]),
            SizedBox(height: ZapSpacing.sm),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('— Beta tester, Samsung S23, Android 13',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10)),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _statChip(String value, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$value $label',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ── Sentry Tab ─────────────────────────────────────────────────────────────────
class _SentryTab extends ConsumerWidget {
  const _SentryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulled = ref.watch(_sentryPulledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.bug_report_rounded,
          color: const Color(0xFFEF4444),
          text: 'Pulling 14-day Sentry window post v0.5-beta-2. '
              'Comparing against Day 121 baseline (first 14 days of beta).',
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (!pulled) ...[
          _codeNote('sentry-cli',
              'sentry-cli releases list\n'
              'sentry-cli stats --org zapsafe --project flutter \\\n'
              '  --since 14d --metric crash_rate'),
          const SizedBox(height: ZapSpacing.md),
          _actionButton(
            label: 'Pull fresh Sentry metrics',
            icon: Icons.cloud_download_rounded,
            color: const Color(0xFFEF4444),
            onTap: () async {
              await Future.delayed(const Duration(milliseconds: 1000));
              if (!context.mounted) return;
              ref.read(_sentryPulledProvider.notifier).state = true;
            },
          ),
        ] else ...[
          // Metric cards
          const _SectionLabel('14-DAY WINDOW  ·  BEFORE vs AFTER v0.5-beta-2'),
          const SizedBox(height: ZapSpacing.md),
          ..._kSentryMetrics.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: _SentryMetricRow(m: m),
              )),
          const SizedBox(height: ZapSpacing.lg),

          // Fix verification grid
          const _SectionLabel('FIX VERIFICATION  ·  TAP FOR EVIDENCE'),
          const SizedBox(height: ZapSpacing.md),
          const _FixVerificationGrid(),
        ],
      ],
    );
  }
}

class _SentryMetricRow extends StatelessWidget {
  final _SentryMetric m;
  const _SentryMetricRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final improvement = (m.improvement * 100).round();
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: m.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: m.color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: m.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(m.icon, color: m.color, size: 17),
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12)),
              Row(children: [
                Text('${_fmt(m.before)}${m.unit}',
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFFEF4444))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF4B5563), size: 11),
                ),
                Text('${_fmt(m.after)}${m.unit}',
                    style: TextStyle(
                        color: m.color,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: m.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            m.lowerIsBetter
                ? '−$improvement%'
                : '+$improvement%',
            style: TextStyle(
                color: m.color,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  String _fmt(double v) =>
      v == v.toInt().toDouble() ? v.toInt().toString() : v.toString();
}

class _FixVerificationGrid extends StatefulWidget {
  const _FixVerificationGrid();

  @override
  State<_FixVerificationGrid> createState() => _FixVerificationGridState();
}

class _FixVerificationGridState extends State<_FixVerificationGrid> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kFixVerifications.asMap().entries.map((e) {
        final i   = e.key;
        final fv  = e.value;
        final isOpen = _expanded == i;

        return GestureDetector(
          onTap: () => setState(() => _expanded = isOpen ? null : i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: isOpen
                  ? fv.color.withOpacity(0.07)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: isOpen
                    ? fv.color.withOpacity(0.4)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: fv.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(fv.version,
                        style: TextStyle(
                            color: fv.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(fv.fix,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    '${_fmtV(fv.beforeVal)} → ${_fmtV(fv.afterVal)}${fv.unit}',
                    style: TextStyle(
                        color: fv.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(
                                ZapSpacing.radiusSmall),
                            border: Border.all(
                                color: const Color(0xFF30363D)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: Color(0xFF79C0FF), size: 13),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(fv.evidence,
                                    style: const TextStyle(
                                        color: Color(0xFFE6EDF3),
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        height: 1.5)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  String _fmtV(double v) =>
      v == v.toInt().toDouble() ? v.toInt().toString() : v.toString();
}

// ── Retention Tab ──────────────────────────────────────────────────────────────
class _RetentionTab extends ConsumerWidget {
  const _RetentionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(_retentionDayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.people_rounded,
          color: const Color(0xFF10B981),
          text: 'Retention = % of testers who open the app again on each day '
              'after installation. A higher Day-7 retention means users '
              'are building a habit. v0.5-beta-2 target: Day-7 > 40%.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Day selector
        const _SectionLabel('SELECT DAY TO INSPECT'),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(14, (i) {
              final day = i + 1;
              final isSelected = day == selectedDay;
              return GestureDetector(
                onTap: () => ref
                    .read(_retentionDayProvider.notifier)
                    .state = day,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text('D$day',
                        style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Retention chart
        const _SectionLabel('RETENTION CURVE  ·  BEFORE vs AFTER'),
        const SizedBox(height: ZapSpacing.md),
        _RetentionChart(selectedDay: selectedDay),
        const SizedBox(height: ZapSpacing.lg),

        // Selected day detail
        _RetentionDayDetail(day: selectedDay),
        const SizedBox(height: ZapSpacing.lg),

        // Key benchmarks
        const _SectionLabel('BENCHMARK COMPARISON'),
        const SizedBox(height: ZapSpacing.md),
        const _RetentionBenchmarks(),
      ],
    );
  }
}

class _RetentionChart extends StatelessWidget {
  final int selectedDay;
  const _RetentionChart({required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    const maxPct = 100.0;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Legend
        Row(children: [
          _legend(const Color(0xFFEF4444).withOpacity(0.5), 'Before (v0.5-beta-1)'),
          const SizedBox(width: ZapSpacing.lg),
          _legend(const Color(0xFF10B981), 'After (v0.5-beta-2)'),
        ]),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(14, (i) {
              final day = i + 1;
              final before = _kRetentionBefore[i];
              final after  = _kRetentionAfter[i];
              final isSelected = day == selectedDay;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // After bar (front)
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Before bar (behind)
                          Container(
                            height: (before / maxPct * 80).clamp(2.0, 80.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.25),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)),
                            ),
                          ),
                          // After bar
                          Container(
                            height: (after / maxPct * 80).clamp(2.0, 80.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF10B981).withOpacity(0.6),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)),
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.white, width: 1)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ZapSpacing.xs),
                      Text('$day',
                          style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF4B5563),
                              fontSize: 7),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 12, height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: ZapSpacing.xs),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 10)),
      ]);
}

class _RetentionDayDetail extends StatelessWidget {
  final int day;
  const _RetentionDayDetail({required this.day});

  @override
  Widget build(BuildContext context) {
    final before = _kRetentionBefore[day - 1];
    final after  = _kRetentionAfter[day - 1];
    final delta  = after - before;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Day $day retention',
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11)),
          Text('${after.round()}%',
              style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
          Text('was ${before.round()}%',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 11)),
        ]),
        const SizedBox(width: ZapSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.trending_up_rounded,
                    color: Color(0xFF10B981), size: 16),
                const SizedBox(width: ZapSpacing.xs),
                Text(
                  '+${delta.round()} pp improvement',
                  style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ]),
              const SizedBox(height: ZapSpacing.xs),
              Text(
                day <= 3
                    ? 'Early retention: users engaged right after install'
                    : day <= 7
                        ? 'Week-1 retention: habit-forming window'
                        : 'Week-2 retention: users who stayed through beta',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RetentionBenchmarks extends StatelessWidget {
  const _RetentionBenchmarks();

  static const _benchmarks = [
    ('Day 1', '78%',  '> 60%',   true),
    ('Day 7', '43%',  '> 30%',   true),
    ('Day 14', '35%', '> 20%',   true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _benchmarks.asMap().entries.map((e) {
          final i = e.key;
          final (day, actual, target, pass) = e.value;
          final isLast = i == _benchmarks.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(children: [
                Text(day,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(actual,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: ZapSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: pass
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pass ? 'target $target ✅' : 'target $target ❌',
                    style: TextStyle(
                      color: pass
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _infoBox({
  required IconData icon,
  required Color color,
  required String text,
}) =>
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
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ),
      ]),
    );

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
          gradient: color == const Color(0xFF4B5563)
              ? null
              : LinearGradient(colors: [color, color.withOpacity(0.8)]),
          color: color == const Color(0xFF4B5563)
              ? const Color(0xFF1A1A1A)
              : null,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: color == const Color(0xFF4B5563)
              ? null
              : [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ],
          border: color == const Color(0xFF4B5563)
              ? Border.all(color: const Color(0xFF2A2A2A))
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: color == const Color(0xFF4B5563)
                  ? const Color(0xFF4B5563)
                  : Colors.white,
              size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: TextStyle(
                  color: color == const Color(0xFF4B5563)
                      ? const Color(0xFF4B5563)
                      : Colors.white,
                  fontSize: 14,
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
            ? SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
                  color: Color(0xFF79C0FF),
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6)),
      ]),
    );
