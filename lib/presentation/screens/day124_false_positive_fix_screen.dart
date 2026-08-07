/// Day 124 — Fix False Positive Confusion (Part 1)
///
/// From Day 121 analysis: 7.8% false positive rate. Root causes:
///   1. No explanation of WHAT triggered the SOS
///   2. No confidence score shown to user
///   3. Threshold too low (0.80) — movie audio / music triggers M1
///
/// This screen builds three fixes:
///   A. Post-SOS Explanation Card — "Scream detected (92%) at 12:45 PM"
///   B. Threshold Adjuster — raise M1 from 0.80 → 0.88
///   C. Detection Model Info — plain-language descriptions of each model
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeFixProvider     = StateProvider<int>((ref) => 0);
final _m1ThresholdProvider   = StateProvider<double>((ref) => 0.80);
final _m2ThresholdProvider   = StateProvider<double>((ref) => 0.75);
final _demoStateProvider     = StateProvider<_DemoState>((ref) => _DemoState.idle);
final _reportedProvider      = StateProvider<_ReportChoice?>((ref) => null);
final _appliedProvider       = StateProvider<List<bool>>(
  (ref) => [false, false, false],
);

enum _DemoState   { idle, triggering, explanation, reported }
enum _ReportChoice { falseAlarm, realEmergency }

// ── Data ───────────────────────────────────────────────────────────────────────
class _DetectionModel {
  final String id;
  final String name;
  final String shortDesc;
  final String triggers;
  final String noTriggers;
  final Color  color;
  final IconData icon;
  const _DetectionModel({
    required this.id,
    required this.name,
    required this.shortDesc,
    required this.triggers,
    required this.noTriggers,
    required this.color,
    required this.icon,
  });
}

const _kModels = [
  _DetectionModel(
    id: 'M1',
    name: 'Scream / Distress',
    shortDesc: 'Detects loud cries, screams, distress vocalisations',
    triggers: 'Scream, cry, shout for help, glass break, distress call',
    noTriggers: 'Movie audio, music, TV shows, singing, loud conversation',
    color: Color(0xFFEF4444),
    icon: Icons.hearing_rounded,
  ),
  _DetectionModel(
    id: 'M2',
    name: 'Motion Anomaly',
    shortDesc: 'Detects sudden impact, fall, struggle, assault motion',
    triggers: 'Fall, tackle, grab, punch, sudden throw',
    noTriggers: 'Running, cycling, gym workout, dancing, sports',
    color: Color(0xFFF97316),
    icon: Icons.vibration_rounded,
  ),
  _DetectionModel(
    id: 'M9',
    name: 'DCS Fusion',
    shortDesc: 'Combines all model scores for final SOS decision',
    triggers: 'Multiple models agree threat score > threshold',
    noTriggers: 'Any single model alone (requires agreement)',
    color: Color(0xFF8B5CF6),
    icon: Icons.hub_rounded,
  ),
];

const _kFixes = [
  'Post-SOS explanation screen (what triggered + confidence)',
  'Raise M1 threshold from 0.80 → 0.88',
  'Add plain-language model descriptions to settings',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day124FalsePositiveFixScreen extends ConsumerWidget {
  const Day124FalsePositiveFixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFix = ref.watch(_activeFixProvider);
    final applied   = ref.watch(_appliedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 124 · Fix False Positives'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Fix selector
            const _SectionLabel('SELECT FIX TO IMPLEMENT'),
            const SizedBox(height: ZapSpacing.md),
            _FixSelector(active: activeFix, applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            // Fix content
            if (activeFix == 0) ...[
              const _SectionLabel('FIX A  ·  POST-SOS EXPLANATION SCREEN'),
              const SizedBox(height: ZapSpacing.md),
              const _ExplanationScreenFix(),
            ],
            if (activeFix == 1) ...[
              const _SectionLabel('FIX B  ·  DETECTION THRESHOLD ADJUSTER'),
              const SizedBox(height: ZapSpacing.md),
              const _ThresholdFix(),
            ],
            if (activeFix == 2) ...[
              const _SectionLabel('FIX C  ·  MODEL INFO IN DETECTION SETTINGS'),
              const SizedBox(height: ZapSpacing.md),
              const _ModelInfoFix(),
            ],
            const SizedBox(height: ZapSpacing.xl),

            // Apply fix button
            _ApplyButton(index: activeFix),
            const SizedBox(height: ZapSpacing.xl),

            // Summary
            const _SectionLabel('FIX PROGRESS'),
            const SizedBox(height: ZapSpacing.md),
            _FixSummary(applied: applied),
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
          colors: [Color(0xFF1A0F00), Color(0xFF0D0800), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 124', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('FP Rate: 7.8% → 5%', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Fix False Positive\nConfusion',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '7.8% of SOS events are false alarms. Users are confused '
            'and scared. Three targeted fixes: explain what triggered, '
            'raise M1 threshold, and add model descriptions.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('7.8%', 'Current FP',   Color(0xFFEF4444)),
            _HStat('→ 5%', 'Target FP',    Color(0xFF10B981)),
            _HStat('3',    'Fixes',         Color(0xFF3B82F6)),
            _HStat('M1',   'Main offender', Color(0xFFF59E0B)),
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
  final Color color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
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

// ── Fix selector ───────────────────────────────────────────────────────────────
class _FixSelector extends ConsumerWidget {
  final int active;
  final List<bool> applied;
  const _FixSelector({required this.active, required this.applied});

  static const _labels = ['Fix A', 'Fix B', 'Fix C'];
  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
  ];
  static const _icons = [
    Icons.info_outline_rounded,
    Icons.tune_rounded,
    Icons.description_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: List.generate(3, (i) {
        final isActive  = i == active;
        final isDone    = applied[i];
        final color     = _colors[i];

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                ref.read(_activeFixProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : _icons[i],
                    color: isDone ? const Color(0xFF10B981) : color,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(_labels[i],
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDone ? 'Applied' : 'Pending',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF4B5563),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Fix A — Post-SOS Explanation Screen ───────────────────────────────────────
class _ExplanationScreenFix extends ConsumerWidget {
  const _ExplanationScreenFix();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(_demoStateProvider);
    final reported  = ref.watch(_reportedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Problem statement
        _infoBox(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          text: 'Problem: SOS fires → user sees red screen with no explanation. '
              '"Why is this happening?" → panic → bad reviews.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Solution description
        _infoBox(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFFF59E0B),
          text: 'Fix: Show a 3-second explanation card between detection and ALERT_PENDING: '
              '"Scream detected (92% confidence) at 12:45 PM. '
              'Cancel within 15 seconds if you are safe."',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Live demo
        const _SectionLabel('LIVE DEMO  ·  TAP TO SIMULATE SOS'),
        const SizedBox(height: ZapSpacing.md),

        if (demoState == _DemoState.idle)
          _actionButton(
            label: 'Simulate SOS trigger',
            icon: Icons.bolt_rounded,
            color: const Color(0xFFEF4444),
            onTap: () async {
              ref.read(_demoStateProvider.notifier).state =
                  _DemoState.triggering;
              await Future.delayed(const Duration(milliseconds: 800));
              if (!context.mounted) return;
              ref.read(_demoStateProvider.notifier).state =
                  _DemoState.explanation;
            },
          )
        else if (demoState == _DemoState.triggering)
          _statusChip(Icons.bolt_rounded, const Color(0xFFEF4444),
              'SOS trigger detected…', loading: true)
        else if (demoState == _DemoState.explanation ||
            demoState == _DemoState.reported) ...[
          // The explanation card itself
          _ExplanationCard(
            reported: reported,
            onFalseAlarm: () {
              ref.read(_reportedProvider.notifier).state =
                  _ReportChoice.falseAlarm;
              ref.read(_demoStateProvider.notifier).state =
                  _DemoState.reported;
            },
            onRealEmergency: () {
              ref.read(_reportedProvider.notifier).state =
                  _ReportChoice.realEmergency;
              ref.read(_demoStateProvider.notifier).state =
                  _DemoState.reported;
            },
          ),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () {
              ref.read(_demoStateProvider.notifier).state = _DemoState.idle;
              ref.read(_reportedProvider.notifier).state = null;
            },
            child: const Center(
              child: Text('Reset demo',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),

        // Code location
        _codeNote(
          'sos_trigger_flow.dart',
          '// Insert explanation card BEFORE navigating to /sos-pending\n'
          'await showExplanationCard(context, triggerReason);\n'
          'context.push(AppRoutes.alertPending);',
        ),
      ],
    );
  }
}

class _ExplanationCard extends StatefulWidget {
  final _ReportChoice? reported;
  final VoidCallback onFalseAlarm;
  final VoidCallback onRealEmergency;
  const _ExplanationCard({
    required this.reported,
    required this.onFalseAlarm,
    required this.onRealEmergency,
  });

  @override
  State<_ExplanationCard> createState() => _ExplanationCardState();
}

class _ExplanationCardState extends State<_ExplanationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReported = widget.reported != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReported
              ? [
                  const Color(0xFF0A1A0A),
                  const Color(0xFF0A0A0A),
                ]
              : [
                  const Color(0xFF1A0505),
                  const Color(0xFF0A0A0A),
                ],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: isReported
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFFEF4444).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: isReported
                        ? const Color(0xFF10B981).withOpacity(
                            0.1 + _pulse.value * 0.05)
                        : const Color(0xFFEF4444).withOpacity(
                            0.15 + _pulse.value * 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isReported
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: isReported
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              Text(
                isReported ? 'Reported — Thank you' : 'SOS Triggered',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),

        // Detection details
        Container(
          margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _detailRow(Icons.hearing_rounded, const Color(0xFFEF4444),
                'Trigger', 'Scream detected'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _detailRow(Icons.percent_rounded, const Color(0xFFF59E0B),
                'Confidence', '92%'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _detailRow(Icons.access_time_rounded, const Color(0xFF3B82F6),
                'Detected at', '12:45 PM'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _detailRow(Icons.timer_rounded, const Color(0xFF8B5CF6),
                'Cancel window', '15 seconds'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Action buttons
        if (!isReported)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.lg),
            child: Column(children: [
              GestureDetector(
                onTap: widget.onFalseAlarm,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: const Center(
                    child: Text('Was this wrong? Report false alarm',
                        style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              GestureDetector(
                onTap: widget.onRealEmergency,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Center(
                    child: Text('Correct — I am in danger',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.25)),
              ),
              child: Text(
                widget.reported == _ReportChoice.falseAlarm
                    ? 'Logged as false alarm — feeds M1 retraining dataset'
                    : 'Real emergency confirmed — escalation continues',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _detailRow(IconData icon, Color color, String label, String value) =>
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text('$label:',
            style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]);
}

// ── Fix B — Threshold Adjuster ─────────────────────────────────────────────────
class _ThresholdFix extends ConsumerWidget {
  const _ThresholdFix();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m1 = ref.watch(_m1ThresholdProvider);
    final m2 = ref.watch(_m2ThresholdProvider);

    // Estimated FP rate based on threshold
    double estimatedFP(double threshold) {
      if (threshold >= 0.90) return 3.1;
      if (threshold >= 0.88) return 4.8;
      if (threshold >= 0.85) return 6.0;
      if (threshold >= 0.80) return 7.8;
      return 10.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          text: 'Problem: M1 Scream model fires at 80% confidence — '
              'too sensitive. Movie audio at 82% confidence triggers SOS.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _infoBox(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFFF59E0B),
          text: 'Fix: Raise threshold to 88%. Reduces false triggers '
              'from media audio while keeping real scream detection at 99%+ accuracy.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Threshold sliders
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // M1 slider
            _ThresholdRow(
              label: 'M1 Scream',
              color: const Color(0xFFEF4444),
              value: m1,
              recommended: 0.88,
              onChanged: (v) =>
                  ref.read(_m1ThresholdProvider.notifier).state = v,
            ),
            const SizedBox(height: ZapSpacing.xl),
            // M2 slider
            _ThresholdRow(
              label: 'M2 Motion',
              color: const Color(0xFFF97316),
              value: m2,
              recommended: 0.75,
              onChanged: (v) =>
                  ref.read(_m2ThresholdProvider.notifier).state = v,
            ),
            const Divider(height: ZapSpacing.xl, color: Color(0xFF2A2A2A)),
            // Estimated FP rate
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated FP rate:',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    '${estimatedFP(m1).toStringAsFixed(1)}%',
                    key: ValueKey(m1),
                    style: TextStyle(
                      color: estimatedFP(m1) <= 5.0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              m1 >= 0.88
                  ? '✅ Recommended threshold applied — target FP rate achieved'
                  : 'Drag M1 slider to 0.88 to hit the 5% target',
              style: TextStyle(
                color: m1 >= 0.88
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
                fontSize: 11,
              ),
            ),
          ],
        )),
      ],
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final double recommended;
  final ValueChanged<double> onChanged;
  const _ThresholdRow({
    required this.label,
    required this.color,
    required this.value,
    required this.recommended,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOptimal = (value - recommended).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text(value.toStringAsFixed(2),
              style: TextStyle(
                  color: isOptimal
                      ? const Color(0xFF10B981)
                      : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
          if (isOptimal) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 16),
          ],
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Row(children: [
          const Text('0.60',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: const Color(0xFF2A2A2A),
                thumbColor: color,
                overlayColor: color.withOpacity(0.15),
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: value,
                min: 0.60,
                max: 0.95,
                divisions: 35,
                onChanged: onChanged,
              ),
            ),
          ),
          const Text('0.95',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
        ]),
        Row(children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Recommended: ${recommended.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Color(0xFFF59E0B), fontSize: 9),
            ),
          ),
        ]),
      ],
    );
  }
}

// ── Fix C — Model Info in Settings ────────────────────────────────────────────
class _ModelInfoFix extends ConsumerWidget {
  const _ModelInfoFix();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          text: 'Problem: Settings → Detection shows only a toggle per model. '
              'Users don\'t know what "M1 Scream" means — they can\'t '
              'judge if a false alarm makes sense.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _infoBox(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Fix: Expand each model row with plain-language description, '
              'examples of what DOES and DOES NOT trigger it.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Model cards
        ..._kModels.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _ModelCard(model: m),
            )),
      ],
    );
  }
}

class _ModelCard extends StatefulWidget {
  final _DetectionModel model;
  const _ModelCard({required this.model});

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _expanded
              ? m.color.withOpacity(0.07)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: _expanded
                ? m.color.withOpacity(0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: m.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(m.icon, color: m.color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: m.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(m.id,
                            style: TextStyle(
                                color: m.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Text(m.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                    Text(m.shortDesc,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            height: 1.3)),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: Column(children: [
                      const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                      _exampleRow(
                          Icons.check_rounded, const Color(0xFF10B981),
                          'TRIGGERS', m.triggers),
                      const SizedBox(height: ZapSpacing.sm),
                      _exampleRow(
                          Icons.close_rounded, const Color(0xFFEF4444),
                          'DOES NOT TRIGGER', m.noTriggers),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _exampleRow(IconData icon, Color color, String label, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 8, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.4)),
        ),
      ]);
}

// ── Apply button ───────────────────────────────────────────────────────────────
class _ApplyButton extends ConsumerWidget {
  final int index;
  const _ApplyButton({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_appliedProvider);
    final isDone  = applied[index];

    if (isDone) {
      return _statusChip(
          Icons.check_circle_rounded, const Color(0xFF10B981),
          'Fix ${String.fromCharCode(65 + index)} applied');
    }

    return _actionButton(
      label: 'Apply Fix ${String.fromCharCode(65 + index)}',
      icon: Icons.build_rounded,
      color: const Color(0xFF3B82F6),
      onTap: () async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
        final updated = List<bool>.from(ref.read(_appliedProvider));
        updated[index] = true;
        ref.read(_appliedProvider.notifier).state = updated;
      },
    );
  }
}

// ── Fix summary ────────────────────────────────────────────────────────────────
class _FixSummary extends StatelessWidget {
  final List<bool> applied;
  const _FixSummary({required this.applied});

  @override
  Widget build(BuildContext context) {
    final doneCount = applied.where((a) => a).length;
    final allDone   = doneCount == 3;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: allDone
            ? const Color(0xFF10B981).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: allDone
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$doneCount / 3 fixes applied',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(
              allDone
                  ? '→ Day 125: test + verify FP rate'
                  : 'Apply remaining fixes above',
              style: TextStyle(
                  color: allDone
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
            value: doneCount / 3,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              allDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ...List.generate(3, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(
                  applied[i]
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: applied[i]
                      ? const Color(0xFF10B981)
                      : const Color(0xFF4B5563),
                  size: 16,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Text(_kFixes[i],
                    style: TextStyle(
                        color: applied[i] ? const Color(0xFF9CA3AF) : Colors.white,
                        fontSize: 12,
                        decoration:
                            applied[i] ? TextDecoration.lineThrough : null,
                        decorationColor: const Color(0xFF6B7280))),
              ]),
            )),
      ]),
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
            borderRadius: BorderRadius.circular(4),
          ),
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

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: child,
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
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
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
