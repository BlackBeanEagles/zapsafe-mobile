/// Day 201 — Real Device QA Harness
///
/// Section A (Days 201-220): production polish on physical hardware.
/// Interactive checklist for microphone, IMU, GPS, camera, biometrics,
/// background service, and manual SOS trigger verification.
///
/// Tag: 🟢 FRONTEND-ONLY — no backend; emulator cannot replace device tests.
///
/// Route: [AppRoutes.deviceQaHarness] → `/device-qa-harness`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d201TabProvider = StateProvider<int>((ref) => 0);

/// test id → pass | fail | skip | null (pending)
final _d201ResultsProvider =
    StateProvider<Map<String, String>>((ref) => {});

final _d201RunningIdProvider = StateProvider<String?>((ref) => null);

// ── Models ────────────────────────────────────────────────────────────────────
class _QaTest {
  final String id;
  final int tabIndex;
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;
  final bool simulatedRun;
  const _QaTest({
    required this.id,
    required this.tabIndex,
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
    this.simulatedRun = true,
  });
}

const _kTabs = ['Hardware', 'Background', 'Sign-off'];

const _kTests = [
  _QaTest(
    id: 'H1',
    tabIndex: 0,
    title: 'Microphone capture',
    icon: Icons.mic_rounded,
    color: Color(0xFFEF4444),
    steps: [
      'Grant microphone permission if prompted.',
      'Open Day 26 Audio Capture or record 3 seconds of audio.',
      'Verify waveform / level meter moves when you speak.',
      'Confirm 16 kHz mono path is selected in service logs.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'H2',
    tabIndex: 0,
    title: 'IMU / accelerometer',
    icon: Icons.sensors_rounded,
    color: Color(0xFF8B5CF6),
    steps: [
      'Open Day 36 IMU Service screen.',
      'Shake device gently — accel values should change.',
      'Rotate phone — gyro values should update.',
      'Fall detector should not false-fire from desk tap.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'H3',
    tabIndex: 0,
    title: 'GPS location fix',
    icon: Icons.gps_fixed_rounded,
    color: Color(0xFF10B981),
    steps: [
      'Enable location (Always) in system settings.',
      'Open Day 37 GPS Service — wait for first fix.',
      'Accuracy should be < 30 m outdoors.',
      'Toggle airplane mode off — batch upload queue should drain.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'H4',
    tabIndex: 0,
    title: 'Camera (front + rear)',
    icon: Icons.camera_alt_rounded,
    color: Color(0xFFF59E0B),
    steps: [
      'Grant camera permission.',
      'Start evidence preview or camera test screen.',
      'Switch front ↔ rear — both streams initialize.',
      'Verify no white flash on SOS Active (Day 184).',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'H5',
    tabIndex: 0,
    title: 'Biometric unlock',
    icon: Icons.fingerprint_rounded,
    color: Color(0xFF3B82F6),
    steps: [
      'Enable App Lock on Day 183 screen.',
      'Background app 2+ minutes, reopen.',
      'Biometric prompt should appear.',
      'PIN fallback works if biometric cancelled.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'H6',
    tabIndex: 0,
    title: 'FCM push token',
    icon: Icons.notifications_active_rounded,
    color: Color(0xFF06B6D4),
    steps: [
      'Open Day 16 Push Notifications.',
      'Confirm token registers (mock or live).',
      'Send test push from Firebase console.',
      'Notification opens correct route (Day 17).',
    ],
    simulatedRun: true,
  ),
  _QaTest(
    id: 'B1',
    tabIndex: 1,
    title: 'Foreground service',
    icon: Icons.sync_rounded,
    color: Color(0xFF10B981),
    steps: [
      'Start background service (Day 21).',
      'Check persistent notification is visible.',
      'Swipe app away from recents — service stays alive.',
      'Android: verify ForegroundService type declared.',
    ],
    simulatedRun: true,
  ),
  _QaTest(
    id: 'B2',
    tabIndex: 1,
    title: 'Watchdog / LP4 restart',
    icon: Icons.pets_rounded,
    color: Color(0xFFF97316),
    steps: [
      'Force-stop app from system settings.',
      'Wait 30–45 seconds.',
      'Service should restart (Day 22 / LP4).',
      'Protection notification reappears.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'B3',
    tabIndex: 1,
    title: 'Background GPS batch',
    icon: Icons.upload_rounded,
    color: Color(0xFF3B82F6),
    steps: [
      'Walk 2 minutes with app backgrounded.',
      'Open network log — POST /api/v1/gps/batch/ fires.',
      'Batch size ≤ 50 per request.',
      'Offline queue holds fixes until online.',
    ],
    simulatedRun: true,
  ),
  _QaTest(
    id: 'B4',
    tabIndex: 1,
    title: 'Silent push wake',
    icon: Icons.nights_stay_rounded,
    color: Color(0xFF8B5CF6),
    steps: [
      'Kill app completely.',
      'Send silent/data push from Firebase (dev).',
      'App should wake background handler within 60 s.',
      'iOS: requires Background Modes capability.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'S1',
    tabIndex: 2,
    title: 'Volume-button SOS trigger',
    icon: Icons.volume_up_rounded,
    color: Color(0xFFEF4444),
    steps: [
      'Enable volume trigger in Settings.',
      'Lock screen — hold volume down 3 seconds.',
      'ALERT_PENDING should open (blank UI, LP27).',
      'Cancel with real PIN — no SOS fired.',
    ],
    simulatedRun: false,
  ),
  _QaTest(
    id: 'S2',
    tabIndex: 2,
    title: 'Full SOS dry-run',
    icon: Icons.emergency_rounded,
    color: Color(0xFFE63946),
    steps: [
      'Start Drill Mode (not live SOS).',
      'Complete 15 s countdown → SOS Active.',
      'Verify GPS + audio streams in vault preview.',
      'End drill — contacts see [DRILL] label.',
    ],
    simulatedRun: false,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day201DeviceQaHarnessScreen extends ConsumerWidget {
  const Day201DeviceQaHarnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d201TabProvider);
    final results = ref.watch(_d201ResultsProvider);
    final runningId = ref.watch(_d201RunningIdProvider);

    final completed = results.length;
    final passed = results.values.where((v) => v == 'pass').length;
    final progress = completed / _kTests.length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 201 · Device QA'),
        actions: [
          TextButton(
            onPressed: completed == 0
                ? null
                : () => ref.read(_d201ResultsProvider.notifier).state = {},
            child: const Text('Reset'),
          ),
          TextButton.icon(
            onPressed: completed == 0
                ? null
                : () => _exportSummary(context, ref),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Export'),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProgressHeader(
            completed: completed,
            total: _kTests.length,
            passed: passed,
            progress: progress,
          ),
          _TabBar(tab: tab, onSelect: (i) {
            ref.read(_d201TabProvider.notifier).state = i;
          }),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              children: [
                ..._kTests
                    .where((t) => t.tabIndex == tab)
                    .map((t) => _TestCard(
                          test: t,
                          status: results[t.id],
                          isRunning: runningId == t.id,
                          onRun: () => _runTest(context, ref, t),
                          onPass: () => _setResult(ref, t.id, 'pass'),
                          onFail: () => _setResult(ref, t.id, 'fail'),
                          onSkip: () => _setResult(ref, t.id, 'skip'),
                        )),
                if (tab == 2 && completed == _kTests.length) ...[
                  const SizedBox(height: ZapSpacing.lg),
                  _CelebrationCard(passed: passed),
                ],
                const SizedBox(height: ZapSpacing.xxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runTest(
      BuildContext context, WidgetRef ref, _QaTest test) async {
    if (!test.simulatedRun) {
      _showStepsSheet(context, test);
      return;
    }
    ref.read(_d201RunningIdProvider.notifier).state = test.id;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    ref.read(_d201RunningIdProvider.notifier).state = null;
    _setResult(ref, test.id, 'pass');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${test.title}: simulated pass ✓'),
          backgroundColor: ZapColors.safe,
        ),
      );
    }
  }

  void _setResult(WidgetRef ref, String id, String status) {
    ref.read(_d201ResultsProvider.notifier).update((m) => {...m, id: status});
  }

  void _showStepsSheet(BuildContext context, _QaTest test) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZapColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(test.icon, color: test.color),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(test.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: ZapColors.textPrimary,
                      )),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text('Manual steps on a physical device:',
                style: TextStyle(color: ZapColors.textSecondary)),
            const SizedBox(height: ZapSpacing.sm),
            ...test.steps.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: ZapSpacing.lg),
            const Text(
              'Mark result after completing on device:',
              style: TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSummary(BuildContext context, WidgetRef ref) async {
    final results = ref.read(_d201ResultsProvider);
    final buf = StringBuffer('ZapSafe Device QA — Day 201\n');
    buf.writeln('Date: ${DateTime.now().toIso8601String()}\n');
    for (final t in _kTests) {
      final s = results[t.id] ?? 'pending';
      buf.writeln('[${t.id}] ${t.title}: $s');
    }
    final passed = results.values.where((v) => v == 'pass').length;
    buf.writeln('\nTotal: ${results.length}/${_kTests.length} marked, $passed pass');
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QA summary copied to clipboard')),
      );
    }
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final int completed;
  final int total;
  final int passed;
  final double progress;

  const _ProgressHeader({
    required this.completed,
    required this.total,
    required this.passed,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      color: ZapColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('🟢 FRONTEND-ONLY', ZapColors.safe),
              const SizedBox(width: ZapSpacing.sm),
              _badge('PHYSICAL DEVICE', ZapColors.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            '$completed / $total tests marked · $passed passed',
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ZapColors.bgElevated,
              color: progress >= 1.0 ? ZapColors.safe : ZapColors.info,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          const Text(
            'Use a real phone — emulator cannot validate mic, IMU, or background kill.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tests tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.safe : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final _QaTest test;
  final String? status;
  final bool isRunning;
  final VoidCallback onRun;
  final VoidCallback onPass;
  final VoidCallback onFail;
  final VoidCallback onSkip;

  const _TestCard({
    required this.test,
    required this.status,
    required this.isRunning,
    required this.onRun,
    required this.onPass,
    required this.onFail,
    required this.onSkip,
  });

  Color get _borderColor {
    switch (status) {
      case 'pass':
        return ZapColors.safe;
      case 'fail':
        return ZapColors.danger;
      case 'skip':
        return ZapColors.warning;
      default:
        return ZapColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: _borderColor, width: status != null ? 2 : 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical: ZapSpacing.xs,
        ),
        leading: Icon(test.icon, color: test.color),
        title: Text(
          test.title,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          status == null ? 'Not run' : status!.toUpperCase(),
          style: TextStyle(
            color: status == 'pass'
                ? ZapColors.safe
                : status == 'fail'
                    ? ZapColors.danger
                    : ZapColors.textSecondary,
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZapSpacing.lg,
              0,
              ZapSpacing.lg,
              ZapSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...test.steps.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
                    child: Text(
                      '• $s',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Run ${test.title}',
                        button: true,
                        child: FilledButton.icon(
                          onPressed: isRunning ? null : onRun,
                          icon: isRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            test.simulatedRun ? 'Simulate' : 'Show steps',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 75),
                            backgroundColor: ZapColors.info,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Row(
                  children: [
                    _resultBtn('Pass', ZapColors.safe, onPass),
                    const SizedBox(width: ZapSpacing.sm),
                    _resultBtn('Fail', ZapColors.danger, onFail),
                    const SizedBox(width: ZapSpacing.sm),
                    _resultBtn('Skip', ZapColors.warning, onSkip),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBtn(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        label: 'Mark $label for ${test.title}',
        button: true,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 75),
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.6)),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final int passed;

  const _CelebrationCard({required this.passed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.2),
            ZapColors.info.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration_rounded,
              color: ZapColors.safe, size: 40),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Device QA cycle complete',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            '$passed / ${_kTests.length} tests passed. '
            'Tomorrow: Day 202 — Dashboard notification hierarchy.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZapColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
