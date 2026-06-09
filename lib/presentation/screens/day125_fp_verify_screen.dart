/// Day 125 — False Positive Verification & ALERT_PENDING Improvement
///
/// Second half of the Days 124-125 false positive fix cycle.
/// Day 124 implemented the fixes. Day 125:
///   1. Improved ALERT_PENDING countdown — shows detection reason + confidence
///      during the 15s window so users understand WHAT triggered the SOS
///   2. FP test scenarios — run each scenario, verify fixes hold
///   3. Before/after FP rate comparison (7.8% → ~4.8%)
///   4. Ship v0.5.2 with all FP fixes bundled
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _countdownProvider    = StateProvider<int>((ref) => 15);
final _countdownRunProvider = StateProvider<bool>((ref) => false);
final _scenarioProvider     = StateProvider<List<_ScenarioResult?>>(
  (ref) => List.filled(_kScenarios.length, null),
);
final _activeScenarioProvider = StateProvider<int>((ref) => 0);
final _shipStateProvider    = StateProvider<_ShipState>((ref) => _ShipState.idle);

enum _ScenarioResult { pass, fail }
enum _ShipState       { idle, building, uploading, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Scenario {
  final String title;
  final String context;
  final String action;
  final String expectedBefore;
  final String expectedAfter;
  final Color  color;
  const _Scenario({
    required this.title,
    required this.context,
    required this.action,
    required this.expectedBefore,
    required this.expectedAfter,
    required this.color,
  });
}

const _kScenarios = [
  _Scenario(
    title: 'Movie scream (M1 threshold fix)',
    context: 'User watching horror movie — loud scream in film',
    action: 'Play 3s horror movie audio near phone microphone',
    expectedBefore: 'SOS fires (M1 confidence 83%) — false alarm',
    expectedAfter: 'No trigger (M1 threshold now 0.88 > 0.83) — PASS',
    color: Color(0xFFEF4444),
  ),
  _Scenario(
    title: 'Running detection (M2 threshold fix)',
    context: 'User jogging in park — motion spikes from footfall',
    action: 'Simulate 30s brisk run with phone in pocket',
    expectedBefore: 'SOS fires occasionally (M2 confidence 77%)',
    expectedAfter: 'No trigger (M2 threshold now 0.75 ≤ 0.77) — borderline; '
        'DCS fusion prevents solo trigger',
    color: Color(0xFFF97316),
  ),
  _Scenario(
    title: 'Real scream still triggers',
    context: 'User shouts loudly for help in test environment',
    action: 'User shouts "HELP!" at 90 dB for 2 seconds',
    expectedBefore: 'SOS fires (M1 confidence 96%) — correct',
    expectedAfter: 'SOS still fires (96% > 0.88 threshold) — correct PASS',
    color: Color(0xFF10B981),
  ),
  _Scenario(
    title: 'Explanation card appears',
    context: 'Real scream detected — explanation card shown before ALERT_PENDING',
    action: 'Verify explanation card shown with trigger, confidence, timestamp',
    expectedBefore: 'No explanation — user confused',
    expectedAfter: '"Scream detected (96%)" card shown for 3s — PASS',
    color: Color(0xFF3B82F6),
  ),
  _Scenario(
    title: 'User cancels after reading explanation',
    context: 'False alarm — user watches movie, SOS fires at 89% confidence',
    action: 'User reads explanation card, taps "Report false alarm"',
    expectedBefore: 'No cancel mechanism before contacts notified',
    expectedAfter: 'Cancel works, false alarm logged to ML dataset — PASS',
    color: Color(0xFF8B5CF6),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day125FpVerifyScreen extends ConsumerWidget {
  const Day125FpVerifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenarios  = ref.watch(_scenarioProvider);
    final passCount  = scenarios.where((s) => s == _ScenarioResult.pass).length;
    final allTested  = scenarios.every((s) => s != null);
    final shipState  = ref.watch(_shipStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 125 · FP Verification'),
        elevation: 0,
        actions: [
          if (allTested && shipState != _ShipState.done)
            TextButton(
              onPressed: () {
                ref.read(_scenarioProvider.notifier).state =
                    List.filled(_kScenarios.length, null);
                ref.read(_shipStateProvider.notifier).state = _ShipState.idle;
                ref.read(_countdownRunProvider.notifier).state = false;
                ref.read(_countdownProvider.notifier).state = 15;
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

            // Improved ALERT_PENDING demo
            const _SectionLabel('IMPROVEMENT  ·  ALERT_PENDING WITH DETECTION REASON'),
            const SizedBox(height: ZapSpacing.md),
            const _AlertPendingDemo(),
            const SizedBox(height: ZapSpacing.xl),

            // Test scenarios
            const _SectionLabel('VERIFICATION SCENARIOS  ·  RUN EACH TEST'),
            const SizedBox(height: ZapSpacing.md),
            _ScenarioPanel(scenarios: scenarios, passCount: passCount),
            const SizedBox(height: ZapSpacing.xl),

            // Before/after FP rate
            const _SectionLabel('FALSE POSITIVE RATE  ·  BEFORE vs AFTER'),
            const SizedBox(height: ZapSpacing.md),
            _FpRateComparison(passCount: passCount, totalTests: _kScenarios.length),
            const SizedBox(height: ZapSpacing.xl),

            // Ship v0.5.2
            const _SectionLabel('SHIP  ·  v0.5.2 FP FIXES BUNDLE'),
            const SizedBox(height: ZapSpacing.md),
            _ShipPanel(allTested: allTested, state: shipState),
            const SizedBox(height: ZapSpacing.xl),

            // Next steps
            const _SectionLabel('NEXT  ·  DAY 126'),
            const SizedBox(height: ZapSpacing.md),
            const _NextCard(),
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
          colors: [Color(0xFF0A150A), Color(0xFF060C06), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 125', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5.2 FP Fixes', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'FP Verify &\nALERT_PENDING UI',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Day 124 applied the three fixes. Today: improve the '
            'ALERT_PENDING countdown to show detection reason, run '
            '5 test scenarios to confirm FP rate dropped, then ship v0.5.2.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5',      'Test scenarios',  Color(0xFF10B981)),
            _HStat('7.8%',   'Before FP',       Color(0xFFEF4444)),
            _HStat('→ 4.8%', 'After FP',        Color(0xFF10B981)),
            _HStat('v0.5.2', 'Ship target',     Color(0xFF3B82F6)),
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
                  fontSize: 14,
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

// ── ALERT_PENDING Demo ─────────────────────────────────────────────────────────
class _AlertPendingDemo extends ConsumerStatefulWidget {
  const _AlertPendingDemo();

  @override
  ConsumerState<_AlertPendingDemo> createState() => _AlertPendingDemoState();
}

class _AlertPendingDemoState extends ConsumerState<_AlertPendingDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _start() async {
    ref.read(_countdownRunProvider.notifier).state = true;
    ref.read(_countdownProvider.notifier).state   = 15;

    for (int i = 15; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (!ref.read(_countdownRunProvider)) {
        ref.read(_countdownProvider.notifier).state = 15;
        return;
      }
      ref.read(_countdownProvider.notifier).state = i;
      if (i == 0) {
        ref.read(_countdownRunProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds  = ref.watch(_countdownProvider);
    final running  = ref.watch(_countdownRunProvider);
    final finished = seconds == 0 && !running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Before/after description
        Row(children: [
          Expanded(
            child: _halfBox(
              label: 'BEFORE (v0.5)',
              text: 'Red screen\nNo explanation\n"Why is this happening?"',
              color: const Color(0xFFEF4444),
              icon: Icons.close_rounded,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: _halfBox(
              label: 'AFTER (v0.5.2)',
              text: 'Shows what triggered\nConfidence %\nCancel reason clear',
              color: const Color(0xFF10B981),
              icon: Icons.check_rounded,
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Mock ALERT_PENDING screen (the improved version)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0005),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: running
                  ? const Color(0xFFEF4444).withOpacity(0.6)
                  : finished
                      ? const Color(0xFF8B5CF6).withOpacity(0.6)
                      : const Color(0xFF2A2A2A),
              width: running ? 2 : 1,
            ),
          ),
          child: Column(children: [
            // Mock app bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 12),
              decoration: BoxDecoration(
                color: running
                    ? const Color(0xFFEF4444).withOpacity(0.15)
                    : const Color(0xFF111111),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ZapSpacing.radius - 1)),
              ),
              child: Row(children: [
                Icon(Icons.warning_rounded,
                    color: running
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4B5563),
                    size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  running ? 'SOS PENDING' : 'ALERT_PENDING',
                  style: TextStyle(
                    color: running ? const Color(0xFFEF4444) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              child: Column(children: [
                // ── NEW: Detection reason banner ──────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(
                    color: running
                        ? const Color(0xFFEF4444).withOpacity(0.1)
                        : const Color(0xFF1A1A1A),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: running
                          ? const Color(0xFFEF4444).withOpacity(0.4)
                          : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.hearing_rounded,
                          color: running
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF4B5563),
                          size: 16),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        running
                            ? 'Scream detected (92% confidence)'
                            : 'Detection reason appears here',
                        style: TextStyle(
                          color: running
                              ? Colors.white
                              : const Color(0xFF4B5563),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                    if (running) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const SizedBox(width: 22),
                        Text('Detected at 12:45 PM · M1 Scream model',
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11)),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: ZapSpacing.xl),

                // Countdown ring
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: running
                          ? const Color(0xFFEF4444).withOpacity(
                              0.1 + _pulseCtrl.value * 0.1)
                          : finished
                              ? const Color(0xFF8B5CF6).withOpacity(0.15)
                              : const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: running
                            ? const Color(0xFFEF4444).withOpacity(
                                0.4 + _pulseCtrl.value * 0.3)
                            : finished
                                ? const Color(0xFF8B5CF6).withOpacity(0.5)
                                : const Color(0xFF2A2A2A),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: finished
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.bolt_rounded,
                                    color: Color(0xFF8B5CF6), size: 32),
                                Text('SOS\nSent',
                                    style: TextStyle(
                                        color: Color(0xFF8B5CF6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  running ? '$seconds' : '15',
                                  style: TextStyle(
                                    color: running
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF4B5563),
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  running ? 'seconds' : 'tap start',
                                  style: const TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 10),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),

                // Cancel button
                if (!finished)
                  GestureDetector(
                    onTap: running
                        ? () {
                            ref.read(_countdownRunProvider.notifier).state =
                                false;
                            ref.read(_countdownProvider.notifier).state = 15;
                          }
                        : _start,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: ZapSpacing.xl),
                      decoration: BoxDecoration(
                        color: running
                            ? const Color(0xFFEF4444).withOpacity(0.15)
                            : const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radiusSmall),
                        border: Border.all(
                          color: running
                              ? const Color(0xFFEF4444).withOpacity(0.5)
                              : const Color(0xFF3B82F6).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        running ? 'Cancel SOS — I am safe' : 'Start demo',
                        style: TextStyle(
                          color: running
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3B82F6),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (finished) ...[
                  const Text('SOS sent to contacts',
                      style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: ZapSpacing.sm),
                  GestureDetector(
                    onTap: () {
                      ref.read(_countdownProvider.notifier).state = 15;
                      ref.read(_countdownRunProvider.notifier).state = false;
                    },
                    child: const Text('Reset demo',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 12)),
                  ),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.md),
        // Code snippet
        _codeNote('alert_pending_screen.dart',
            '// NEW in v0.5.2: show detection reason during countdown\n'
            'DetectionReasonBanner(\n'
            '  trigger: event.triggerModel,   // "M1 Scream"\n'
            '  confidence: event.confidence,  // 0.92\n'
            '  detectedAt: event.timestamp,\n'
            ')'),
      ],
    );
  }

  Widget _halfBox({
    required String label,
    required String text,
    required Color color,
    required IconData icon,
  }) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 6),
            Text(text,
                style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
          ],
        ),
      );
}

// ── Scenario panel ─────────────────────────────────────────────────────────────
class _ScenarioPanel extends ConsumerWidget {
  final List<_ScenarioResult?> scenarios;
  final int passCount;
  const _ScenarioPanel(
      {required this.scenarios, required this.passCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_activeScenarioProvider);

    return Column(
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius)),
            border: const Border(
              left: BorderSide(color: Color(0xFF2A2A2A)),
              right: BorderSide(color: Color(0xFF2A2A2A)),
              top: BorderSide(color: Color(0xFF2A2A2A)),
            ),
          ),
          child: Row(children: [
            Text('$passCount / ${_kScenarios.length} passed',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              passCount == _kScenarios.length
                  ? '✅ All tests pass!'
                  : 'Run each scenario below',
              style: TextStyle(
                  color: passCount == _kScenarios.length
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                  fontSize: 11),
            ),
          ]),
        ),
        ClipRRect(
          child: LinearProgressIndicator(
            value: passCount / _kScenarios.length,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              passCount == _kScenarios.length
                  ? const Color(0xFF10B981)
                  : const Color(0xFF3B82F6),
            ),
            minHeight: 4,
          ),
        ),
        // Scenario cards
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(ZapSpacing.radius)),
            border: const Border(
              left: BorderSide(color: Color(0xFF2A2A2A)),
              right: BorderSide(color: Color(0xFF2A2A2A)),
              bottom: BorderSide(color: Color(0xFF2A2A2A)),
            ),
          ),
          child: Column(
            children: _kScenarios.asMap().entries.map((e) {
              final i        = e.key;
              final scenario = e.value;
              final result   = scenarios[i];
              final isActive = i == active;
              final isLast   = i == _kScenarios.length - 1;

              return Column(children: [
                GestureDetector(
                  onTap: () => ref
                      .read(_activeScenarioProvider.notifier)
                      .state = isActive ? -1 : i,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    color: isActive
                        ? scenario.color.withOpacity(0.06)
                        : Colors.transparent,
                    child: Row(children: [
                      // Number / result badge
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: result == _ScenarioResult.pass
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : result == _ScenarioResult.fail
                                  ? const Color(0xFFEF4444).withOpacity(0.12)
                                  : scenario.color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: result != null
                              ? Icon(
                                  result == _ScenarioResult.pass
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  color: result == _ScenarioResult.pass
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  size: 16)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                      color: scenario.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(scenario.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            if (!isActive)
                              Text(scenario.context,
                                  style: const TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (result == null)
                        Icon(
                          isActive
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF4B5563), size: 18),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: isActive
                      ? _ScenarioDetail(
                          scenario: scenario,
                          index: i,
                          result: result,
                        )
                      : const SizedBox.shrink(),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ScenarioDetail extends ConsumerWidget {
  final _Scenario scenario;
  final int index;
  final _ScenarioResult? result;
  const _ScenarioDetail(
      {required this.scenario, required this.index, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),

        // Context
        _detailRow(Icons.info_outline_rounded, const Color(0xFF3B82F6),
            'Context', scenario.context),
        const SizedBox(height: ZapSpacing.sm),

        // Action
        _detailRow(Icons.play_circle_outline_rounded,
            const Color(0xFF8B5CF6), 'Action', scenario.action),
        const SizedBox(height: ZapSpacing.sm),

        // Before
        _detailRow(Icons.close_rounded, const Color(0xFFEF4444),
            'Before v0.5.2', scenario.expectedBefore),
        const SizedBox(height: ZapSpacing.sm),

        // After
        _detailRow(Icons.check_rounded, const Color(0xFF10B981),
            'After v0.5.2', scenario.expectedAfter),
        const SizedBox(height: ZapSpacing.lg),

        // Pass/fail buttons
        if (result == null)
          Row(children: [
            Expanded(
              child: _resultBtn(
                label: 'Pass',
                icon: Icons.check_rounded,
                color: const Color(0xFF10B981),
                onTap: () {
                  final updated = List<_ScenarioResult?>.from(
                      ref.read(_scenarioProvider));
                  updated[index] = _ScenarioResult.pass;
                  ref.read(_scenarioProvider.notifier).state = updated;
                  // Auto advance
                  if (index < _kScenarios.length - 1) {
                    ref.read(_activeScenarioProvider.notifier).state =
                        index + 1;
                  }
                },
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _resultBtn(
                label: 'Fail',
                icon: Icons.close_rounded,
                color: const Color(0xFFEF4444),
                onTap: () {
                  final updated = List<_ScenarioResult?>.from(
                      ref.read(_scenarioProvider));
                  updated[index] = _ScenarioResult.fail;
                  ref.read(_scenarioProvider.notifier).state = updated;
                  if (index < _kScenarios.length - 1) {
                    ref.read(_activeScenarioProvider.notifier).state =
                        index + 1;
                  }
                },
              ),
            ),
          ])
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: result == _ScenarioResult.pass
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: result == _ScenarioResult.pass
                    ? const Color(0xFF10B981).withOpacity(0.35)
                    : const Color(0xFFEF4444).withOpacity(0.35),
              ),
            ),
            child: Center(
              child: Text(
                result == _ScenarioResult.pass ? '✅ PASS' : '❌ FAIL',
                style: TextStyle(
                  color: result == _ScenarioResult.pass
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _detailRow(
          IconData icon, Color color, String label, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: ZapSpacing.sm),
        Text('$label: ',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
        ),
      ]);

  Widget _resultBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

// ── FP Rate Comparison ─────────────────────────────────────────────────────────
class _FpRateComparison extends StatelessWidget {
  final int passCount;
  final int totalTests;
  const _FpRateComparison(
      {required this.passCount, required this.totalTests});

  @override
  Widget build(BuildContext context) {
    const before = 7.8;
    // Interpolate towards 4.8 as tests pass
    final after =
        before - (before - 4.8) * (passCount / totalTests);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _RateBox('Before', '7.8%', const Color(0xFFEF4444)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: Column(children: [
              const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFF4B5563), size: 20),
              const SizedBox(height: 4),
              Text('${passCount}/${totalTests}\ntests pass',
                  style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 9),
                  textAlign: TextAlign.center),
            ]),
          ),
          Expanded(
            child: _RateBox(
              'After',
              '${after.toStringAsFixed(1)}%',
              after <= 5.0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Visual progress towards target
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Target: < 5.0%',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 11)),
              Text(
                after <= 5.0 ? '✅ Target achieved' : 'In progress…',
                style: TextStyle(
                  color: after <= 5.0
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Stack(children: [
            // Background bar (full = 10% max)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1.0,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF2A2A2A)),
                minHeight: 12,
              ),
            ),
            // Before bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: before / 10.0,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                    const Color(0xFFEF4444).withOpacity(0.25)),
                minHeight: 12,
              ),
            ),
            // After bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: after / 10.0,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    after <= 5.0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  minHeight: 12,
                ),
              ),
            ),
            // Target marker
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 * 0.27,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: const Color(0xFFF59E0B).withOpacity(0.7),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%',
                  style: TextStyle(
                      color: Color(0xFF4B5563), fontSize: 9)),
              Text('5% target',
                  style: TextStyle(
                      color: Color(0xFFF59E0B), fontSize: 9)),
              Text('10%',
                  style: TextStyle(
                      color: Color(0xFF4B5563), fontSize: 9)),
            ],
          ),
        ]),
      ]),
    );
  }
}

class _RateBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RateBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11)),
          const Text('FP rate',
              style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
        ]),
      );
}

// ── Ship Panel ─────────────────────────────────────────────────────────────────
class _ShipPanel extends ConsumerWidget {
  final bool allTested;
  final _ShipState state;
  const _ShipPanel({required this.allTested, required this.state});

  static const _kStates = [
    _ShipState.idle,
    _ShipState.building,
    _ShipState.uploading,
    _ShipState.done,
  ];
  static const _kLabels = [
    '',
    'Building release AAB + IPA…',
    'Uploading to TestFlight + Play…',
    'v0.5.2 live — FP fixes shipped!',
  ];
  static const _kColors = [
    Color(0xFF3B82F6),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _ShipState.done
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // What's in v0.5.2
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          margin: const EdgeInsets.only(bottom: ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius:
                BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('v0.5.2 — False Positive Fixes',
                  style: TextStyle(
                      color: Color(0xFF79C0FF),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700)),
              SizedBox(height: ZapSpacing.sm),
              Text(
                '✨ Post-SOS explanation card (trigger + confidence)\n'
                '✨ ALERT_PENDING shows detection reason during countdown\n'
                '⚡ M1 threshold 0.80 → 0.88 (reduces movie FP)\n'
                '⚡ M2 threshold adjusted for DCS fusion gating\n'
                '✨ Detection model info in Settings → Detection',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.6),
              ),
            ],
          ),
        ),

        if (!allTested && state == _ShipState.idle)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B), size: 14),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                    'Complete all 5 test scenarios before shipping',
                    style: TextStyle(
                        color: Color(0xFFF59E0B), fontSize: 11)),
              ),
            ]),
          ),

        if (state == _ShipState.done) ...[
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.2 shipped!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'FP rate: 7.8% → 4.8% · 847 testers updated · '
            'Days 124-125 complete.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ] else if (state != _ShipState.idle)
          ...List.generate(3, (i) {
            final idx      = _kStates.indexOf(state);
            final isDone   = i + 1 < idx;
            final isActive = i + 1 == idx;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : isActive
                            ? _kColors[i + 1].withOpacity(0.15)
                            : const Color(0xFF111111),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : isActive
                              ? _kColors[i + 1].withOpacity(0.6)
                              : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF10B981), size: 14)
                      : isActive
                          ? Padding(
                              padding: const EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                  color: _kColors[i + 1],
                                  strokeWidth: 2))
                          : null,
                ),
                const SizedBox(width: ZapSpacing.md),
                Text(_kLabels[i + 1],
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF6B7280)
                          : isActive
                              ? Colors.white
                              : const Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    )),
              ]),
            );
          })
        else
          GestureDetector(
            onTap: allTested
                ? () async {
                    for (final s in _kStates.skip(1)) {
                      if (!context.mounted) return;
                      ref.read(_shipStateProvider.notifier).state = s;
                      await Future.delayed(
                          const Duration(milliseconds: 950));
                    }
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: allTested
                    ? const LinearGradient(colors: [
                        Color(0xFF059669),
                        Color(0xFF10B981),
                      ])
                    : null,
                color: allTested ? null : const Color(0xFF111111),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: allTested
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
                border: allTested
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: allTested
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 18),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    allTested
                        ? 'Ship v0.5.2 — FP fixes bundle'
                        : 'Run all scenarios first',
                    style: TextStyle(
                      color: allTested
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Next Card ──────────────────────────────────────────────────────────────────
class _NextCard extends StatelessWidget {
  const _NextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          _nextRow(const Color(0xFFF59E0B), 'Day 126',
              'Fix UI bugs — Hindi text overflow, WCAG contrast, API 29 icon tint'),
          const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
          _nextRow(const Color(0xFF3B82F6), 'Days 127-128',
              'Fix Samsung Android 13 notification delay — Doze mode + SCHEDULE_EXACT_ALARM'),
          const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
          _nextRow(const Color(0xFF8B5CF6), 'Days 129-130',
              'Performance optimisation — cold start 5s → 2s, battery drain, memory'),
        ],
      ),
    );
  }

  Widget _nextRow(Color color, String days, String action) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 8, height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            Text(action,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.4)),
          ]),
        ),
      ]);
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
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
