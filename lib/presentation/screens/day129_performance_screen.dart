/// Day 129 — Performance Optimisation (Part 1)
///
/// Three performance problems from beta metrics (Days 121-128):
///   Problem 1 — Cold start: 5.2s to home screen (target < 2s)
///   Problem 2 — Battery drain: 20% per hour in MONITORING mode (target < 7%)
///   Problem 3 — Memory: 195 MB peak RAM (target < 120 MB)
///
/// Day 129 fixes Problems 1 & 2.
/// Day 130 tackles memory + lazy loading + low-RAM device optimisation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _profileRunProvider   = StateProvider<_ProfileState>((ref) => _ProfileState.idle);
final _appliedProvider      = StateProvider<List<bool>>(
  (ref) => List.filled(_kOptimisations.length, false),
);
final _batterySimProvider   = StateProvider<_BatterySim>((ref) => _BatterySim.idle);

enum _ProfileState { idle, profiling, done }
enum _BatterySim   { idle, running, optimised }

// ── Data ───────────────────────────────────────────────────────────────────────
class _StartupTask {
  final String name;
  final int    durationMs;
  final bool   critical;
  final Color  color;
  final String action;
  const _StartupTask({
    required this.name,
    required this.durationMs,
    required this.critical,
    required this.color,
    required this.action,
  });
}

const _kStartupTasks = [
  _StartupTask(
    name: 'Dart VM initialise',
    durationMs: 210,
    critical: true,
    color: Color(0xFF3B82F6),
    action: 'Cannot defer — Dart runtime required',
  ),
  _StartupTask(
    name: 'Firebase init',
    durationMs: 480,
    critical: true,
    color: Color(0xFFF59E0B),
    action: 'Cannot defer — FCM token needed',
  ),
  _StartupTask(
    name: 'Auth token check',
    durationMs: 120,
    critical: true,
    color: Color(0xFF10B981),
    action: 'Cannot defer — routing depends on auth state',
  ),
  _StartupTask(
    name: 'SQLite / Hive open',
    durationMs: 860,
    critical: false,
    color: Color(0xFFEF4444),
    action: 'DEFER → open lazily on first DB access',
  ),
  _StartupTask(
    name: 'TFLite model load',
    durationMs: 1240,
    critical: false,
    color: Color(0xFFEF4444),
    action: 'DEFER → load in background isolate after first frame',
  ),
  _StartupTask(
    name: 'GPS service start',
    durationMs: 640,
    critical: false,
    color: Color(0xFFEF4444),
    action: 'DEFER → start after home screen renders',
  ),
  _StartupTask(
    name: 'Analytics init',
    durationMs: 420,
    critical: false,
    color: Color(0xFFEF4444),
    action: 'DEFER → start 3s after launch',
  ),
  _StartupTask(
    name: 'Home screen render',
    durationMs: 230,
    critical: true,
    color: Color(0xFF8B5CF6),
    action: 'Target: first frame < 800ms total',
  ),
];

class _Optimisation {
  final String title;
  final String area;
  final Color  color;
  final String before;
  final String after;
  final String desc;
  final String codeFile;
  final String codeBefore;
  final String codeAfter;
  const _Optimisation({
    required this.title,
    required this.area,
    required this.color,
    required this.before,
    required this.after,
    required this.desc,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
  });
}

const _kOptimisations = [
  _Optimisation(
    title: 'Defer DB + TFLite + GPS init',
    area: 'Cold start',
    color: Color(0xFF3B82F6),
    before: '5.2s', after: '1.8s',
    desc: 'Move SQLite, TFLite model load, and GPS service '
        'start to post-first-frame. Only Dart, Firebase, and '
        'auth check run at startup.',
    codeFile: 'main.dart',
    codeBefore:
        'void main() async {\n'
        '  await Hive.initFlutter();        // 860ms\n'
        '  await TFLiteEngine.init();       // 1240ms\n'
        '  await GpsService.start();        // 640ms\n'
        '  runApp(ProviderScope(child: App()));\n'
        '}',
    codeAfter:
        'void main() async {\n'
        '  // Critical only — 810ms total\n'
        '  await Firebase.initializeApp();\n'
        '  await AuthService.hydrateToken();\n'
        '  runApp(ProviderScope(child: App()));\n'
        '  // Deferred — start after first frame\n'
        '  WidgetsBinding.instance.addPostFrameCallback((_) {\n'
        '    _deferredInit();  // Hive + TFLite + GPS\n'
        '  });\n'
        '}',
  ),
  _Optimisation(
    title: 'Reduce GPS poll rate in IDLE state',
    area: 'Battery',
    color: Color(0xFF10B981),
    before: '20%/hr', after: '6%/hr',
    desc: 'GPS polling every 5s drains battery regardless of app '
        'state. In MONITORING (normal) mode use 30s intervals. '
        'In SOS_ACTIVE use 3s. Save ~14% battery per hour.',
    codeFile: 'gps_service.dart',
    codeBefore:
        '// Always polling every 5 seconds\n'
        'const _kInterval = Duration(seconds: 5);\n'
        '_locationStream = Geolocator.getPositionStream(\n'
        '  locationSettings: LocationSettings(\n'
        '    accuracy: LocationAccuracy.high,\n'
        '    distanceFilter: 0,\n'
        '  ),\n'
        ');',
    codeAfter:
        '// Interval depends on app state\n'
        'Duration get _interval => switch (appState) {\n'
        '  AppState.sosActive    => Duration(seconds: 3),\n'
        '  AppState.monitoring   => Duration(seconds: 30),\n'
        '  AppState.idle         => Duration(minutes: 5),\n'
        '  _ => Duration(seconds: 30),\n'
        '};\n'
        '_locationStream = Geolocator.getPositionStream(\n'
        '  locationSettings: LocationSettings(\n'
        '    accuracy: _interval.inSeconds <= 5\n'
        '        ? LocationAccuracy.high\n'
        '        : LocationAccuracy.medium,\n'
        '  ),\n'
        ');',
  ),
  _Optimisation(
    title: 'Batch audio feature extraction',
    area: 'Battery',
    color: Color(0xFFF59E0B),
    before: '20%/hr', after: '4%/hr',
    desc: 'Audio capture runs at 10 Hz extracting MFCC features '
        'every 100ms. Batch to 500ms windows — 5× less CPU '
        'with same detection accuracy.',
    codeFile: 'audio_capture_service.dart',
    codeBefore:
        '// Runs every 100ms — high CPU\n'
        'Timer.periodic(Duration(milliseconds: 100), (_) {\n'
        '  _extractFeatures(_buffer);\n'
        '  _runInference(_features);\n'
        '});',
    codeAfter:
        '// Batch to 500ms window — 5x less CPU\n'
        'Timer.periodic(Duration(milliseconds: 500), (_) {\n'
        '  if (_buffer.length < _kMinSamples) return;\n'
        '  _extractFeatures(_buffer);\n'
        '  _runInference(_features);\n'
        '  _buffer.clear();\n'
        '});',
  ),
];

class _BatteryProcess {
  final String name;
  final double pctBefore;
  final double pctAfter;
  final Color  color;
  const _BatteryProcess(this.name, this.pctBefore, this.pctAfter, this.color);
}

const _kBatteryProcesses = [
  _BatteryProcess('GPS polling',        8.2, 1.4, Color(0xFF3B82F6)),
  _BatteryProcess('Audio extraction',   6.8, 1.2, Color(0xFF8B5CF6)),
  _BatteryProcess('Screen',             2.1, 2.1, Color(0xFFF59E0B)),
  _BatteryProcess('FCM / networking',   1.4, 1.0, Color(0xFF10B981)),
  _BatteryProcess('TFLite inference',   1.1, 0.5, Color(0xFFEF4444)),
  _BatteryProcess('Other',              0.4, 0.4, Color(0xFF9CA3AF)),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day129PerformanceScreen extends ConsumerWidget {
  const Day129PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab     = ref.watch(_activeTabProvider);
    final applied = ref.watch(_appliedProvider);
    final allDone = applied.every((a) => a);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 129 · Performance'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Tab
            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _ColdStartTab(),
            if (tab == 1) const _BatteryTab(),
            const SizedBox(height: ZapSpacing.xl),

            // Optimisations
            const _SectionLabel('APPLY OPTIMISATIONS'),
            const SizedBox(height: ZapSpacing.md),
            _OptimisationList(applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            // Before/after summary
            const _SectionLabel('METRICS  ·  BEFORE vs AFTER'),
            const SizedBox(height: ZapSpacing.md),
            _MetricsSummary(applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            if (allDone) ...[
              const _SectionLabel('DAY 129 COMPLETE'),
              const SizedBox(height: ZapSpacing.md),
              const _CompletionCard(),
              const SizedBox(height: ZapSpacing.xl),
            ],

            const _SectionLabel('NEXT  ·  DAY 130'),
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
          colors: [Color(0xFF100A1E), Color(0xFF080510), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 129', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Cold start + Battery', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Performance\nOptimisation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Beta metrics show cold start at 5.2s and battery drain at '
            '20%/hr — both failing targets. Day 129 fixes cold start '
            'via deferred init and battery via adaptive GPS + batched audio.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5.2s',   'Cold start',   Color(0xFFEF4444)),
            _HStat('→ 1.8s', 'Target',       Color(0xFF10B981)),
            _HStat('20%/hr', 'Battery',      Color(0xFFEF4444)),
            _HStat('→ 6%',   'Target',       Color(0xFF10B981)),
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
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
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
      (Icons.timer_rounded,          Color(0xFF3B82F6),  'Cold Start'),
      (Icons.battery_alert_rounded,  Color(0xFF10B981),  'Battery'),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isActive ? color : const Color(0xFF6B7280),
                      size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color:
                              isActive ? color : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Cold Start Tab ─────────────────────────────────────────────────────────────
class _ColdStartTab extends ConsumerWidget {
  const _ColdStartTab();

  int get _totalMs =>
      _kStartupTasks.fold(0, (s, t) => s + t.durationMs);

  int get _deferredMs => _kStartupTasks
      .where((t) => !t.critical)
      .fold(0, (s, t) => s + t.durationMs);

  int get _criticalMs => _totalMs - _deferredMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(_profileRunProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Context
        _infoBox(
          icon: Icons.speed_rounded,
          color: const Color(0xFFEF4444),
          text: 'Flutter DevTools profile shows 5.2s to first frame. '
              'The bottleneck: SQLite (860ms), TFLite model load (1240ms), '
              'and GPS service start (640ms) all blocking main isolate.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Profile button
        const _SectionLabel('STARTUP PROFILER  ·  FLUTTER DEVTOOLS'),
        const SizedBox(height: ZapSpacing.md),
        _ProfilerCard(state: profileState),
        const SizedBox(height: ZapSpacing.lg),

        // Waterfall chart (always visible)
        const _SectionLabel('STARTUP WATERFALL  ·  BEFORE'),
        const SizedBox(height: ZapSpacing.md),
        _WaterfallChart(tasks: _kStartupTasks, totalMs: _totalMs),
        const SizedBox(height: ZapSpacing.lg),

        // After: critical only
        const _SectionLabel('STARTUP WATERFALL  ·  AFTER (DEFERRED)'),
        const SizedBox(height: ZapSpacing.md),
        _WaterfallChart(
          tasks: _kStartupTasks,
          totalMs: _totalMs,
          deferredMode: true,
          criticalMs: _criticalMs,
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Saving summary
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.bolt_rounded,
                color: Color(0xFF10B981), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Deferring 4 tasks saves ${_deferredMs}ms '
                '(${(_deferredMs / _totalMs * 100).round()}% of total startup). '
                'First frame: ${_criticalMs}ms ≈ 0.8s ✅',
                style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                    height: 1.5),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _ProfilerCard extends ConsumerWidget {
  final _ProfileState state;
  const _ProfilerCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _ProfileState.done
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // Command
        _codeNote('terminal',
            'flutter run --profile\n'
            '# Open DevTools → Performance → Record'),
        const SizedBox(height: ZapSpacing.md),

        if (state == _ProfileState.idle)
          _actionButton(
            label: 'Run profiler simulation',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              ref.read(_profileRunProvider.notifier).state =
                  _ProfileState.profiling;
              await Future.delayed(const Duration(milliseconds: 1600));
              if (!context.mounted) return;
              ref.read(_profileRunProvider.notifier).state =
                  _ProfileState.done;
            },
          )
        else if (state == _ProfileState.profiling)
          _statusChip(Icons.memory_rounded, const Color(0xFF3B82F6),
              'Profiling startup frames…', loading: true)
        else ...[
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              'Profile complete — bottlenecks identified'),
          const SizedBox(height: ZapSpacing.md),
          Row(children: [
            _metricBox('5.2s', 'Time to home', const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _metricBox('3.16s', 'Deferrable', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _metricBox('810ms', 'Critical path', const Color(0xFF10B981)),
          ]),
        ],
      ]),
    );
  }
}

class _WaterfallChart extends StatelessWidget {
  final List<_StartupTask> tasks;
  final int totalMs;
  final bool deferredMode;
  final int criticalMs;

  const _WaterfallChart({
    required this.tasks,
    required this.totalMs,
    this.deferredMode = false,
    this.criticalMs = 0,
  });

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
          // Total time header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                deferredMode ? 'Critical path only' : 'All tasks blocking',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11),
              ),
              Text(
                deferredMode
                    ? '${criticalMs}ms (${(criticalMs/1000).toStringAsFixed(1)}s)'
                    : '${totalMs}ms (${(totalMs/1000).toStringAsFixed(1)}s)',
                style: TextStyle(
                  color: deferredMode
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          ...tasks.map((task) {
            final isDeferred = !task.critical;
            final showAsDeferred = deferredMode && isDeferred;
            final barWidth = task.durationMs / totalMs;
            final barColor = showAsDeferred
                ? const Color(0xFF2A2A2A)
                : task.color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    task.name,
                    style: TextStyle(
                      color: showAsDeferred
                          ? const Color(0xFF4B5563)
                          : Colors.white,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Stack(children: [
                    // Background
                    Container(
                        height: 22,
                        color: const Color(0xFF111111)),
                    // Bar
                    FractionallySizedBox(
                      widthFactor: barWidth,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: barColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Label
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            showAsDeferred
                                ? 'deferred'
                                : '${task.durationMs}ms',
                            style: TextStyle(
                              color: showAsDeferred
                                  ? const Color(0xFF4B5563)
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Icon(
                  showAsDeferred
                      ? Icons.schedule_rounded
                      : task.critical
                          ? Icons.lock_rounded
                          : Icons.block_rounded,
                  color: showAsDeferred
                      ? const Color(0xFF4B5563)
                      : task.critical
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFEF4444),
                  size: 12,
                ),
              ]),
            );
          }),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: [
            _legend(const Color(0xFF3B82F6), 'Critical'),
            const SizedBox(width: ZapSpacing.md),
            _legend(const Color(0xFFEF4444), 'Deferrable'),
            if (deferredMode) ...[
              const SizedBox(width: ZapSpacing.md),
              _legend(const Color(0xFF2A2A2A), 'Deferred'),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 9)),
      ]);
}

// ── Battery Tab ────────────────────────────────────────────────────────────────
class _BatteryTab extends ConsumerWidget {
  const _BatteryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(_batterySimProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.battery_alert_rounded,
          color: const Color(0xFFEF4444),
          text: 'Beta tester report: "App drains 20% battery per hour '
              'while running in background." GPS polling every 5s and '
              'audio extraction every 100ms are the main culprits.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Battery breakdown
        const _SectionLabel('BATTERY DRAIN BY PROCESS'),
        const SizedBox(height: ZapSpacing.md),
        _BatteryBreakdown(showOptimised: sim == _BatterySim.optimised),
        const SizedBox(height: ZapSpacing.lg),

        // Simulate
        const _SectionLabel('SIMULATE  ·  10 MINUTES IN MONITORING MODE'),
        const SizedBox(height: ZapSpacing.md),
        _BatterySimCard(state: sim),
        const SizedBox(height: ZapSpacing.lg),

        // Adaptive GPS explanation
        const _SectionLabel('ADAPTIVE GPS INTERVALS'),
        const SizedBox(height: ZapSpacing.md),
        const _AdaptiveGpsCard(),
      ],
    );
  }
}

class _BatteryBreakdown extends StatelessWidget {
  final bool showOptimised;
  const _BatteryBreakdown({required this.showOptimised});

  @override
  Widget build(BuildContext context) {
    final total = _kBatteryProcesses.fold(
        0.0, (s, p) => s + (showOptimised ? p.pctAfter : p.pctBefore));

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(children: [
          Text(
            '${total.toStringAsFixed(1)}%/hr',
            style: TextStyle(
              color: total > 10
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              showOptimised ? 'After optimisation' : 'Before (beta)',
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11)),
            Text(
              showOptimised ? '✅ Target < 7%' : '❌ Target: < 7%',
              style: TextStyle(
                  color: showOptimised
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ]),
        ]),
        const SizedBox(height: ZapSpacing.lg),
        ..._kBatteryProcesses.map((p) {
          final pct =
              showOptimised ? p.pctAfter : p.pctBefore;
          final maxPct = 10.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Row(children: [
              SizedBox(
                width: 130,
                child: Text(p.name,
                    style: const TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 12)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    child: LinearProgressIndicator(
                      value: pct / maxPct,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation(p.color),
                      minHeight: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              SizedBox(
                width: 44,
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: p.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.end,
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _BatterySimCard extends ConsumerWidget {
  final _BatterySim state;
  const _BatterySimCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        if (state == _BatterySim.idle)
          Row(children: [
            Expanded(
              child: _simBtn(
                'Without fix\n(20%/hr)',
                const Color(0xFFEF4444),
                () => ref.read(_batterySimProvider.notifier).state =
                    _BatterySim.running,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _simBtn(
                'With fix\n(6%/hr)',
                const Color(0xFF10B981),
                () => ref.read(_batterySimProvider.notifier).state =
                    _BatterySim.optimised,
              ),
            ),
          ])
        else ...[
          _BatteryGauge(
              pct: state == _BatterySim.running ? 96.7 : 99.0,
              drain: state == _BatterySim.running
                  ? '−3.3% in 10 min (20%/hr)'
                  : '−1.0% in 10 min (6%/hr)',
              color: state == _BatterySim.running
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981)),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () => ref
                .read(_batterySimProvider.notifier)
                .state = _BatterySim.idle,
            child: const Center(
              child: Text('Reset',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _simBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius:
                BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
        ),
      );
}

class _BatteryGauge extends StatelessWidget {
  final double pct;
  final String drain;
  final Color  color;
  const _BatteryGauge(
      {required this.pct, required this.drain, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.battery_full_rounded, color: color, size: 28),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w900),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(drain,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      const Text('After 10 minutes in MONITORING mode',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
    ]);
  }
}

class _AdaptiveGpsCard extends StatelessWidget {
  const _AdaptiveGpsCard();

  static const _states = [
    (Icons.bolt_rounded,    Color(0xFFEF4444),  'SOS Active',   '3s', 'High accuracy · recording evidence'),
    (Icons.shield_rounded,  Color(0xFF10B981),  'Monitoring',   '30s','Medium accuracy · normal protection'),
    (Icons.bedtime_rounded, Color(0xFF3B82F6),  'Idle / Screen off', '5m','Low accuracy · battery saver'),
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
        children: _states.asMap().entries.map((e) {
          final i = e.key;
          final (icon, color, state, interval, desc) = e.value;
          final isLast = i == _states.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
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
                      Text(state,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(desc,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    'every $interval',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace'),
                  ),
                ),
              ]),
            ),
            if (!isLast)
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Optimisation List ──────────────────────────────────────────────────────────
class _OptimisationList extends ConsumerWidget {
  final List<bool> applied;
  const _OptimisationList({required this.applied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: _kOptimisations.asMap().entries.map((e) {
        final i    = e.key;
        final opt  = e.value;
        final done = applied[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: _OptCard(opt: opt, done: done, onApply: () async {
            await Future.delayed(const Duration(milliseconds: 500));
            if (!context.mounted) return;
            final updated = List<bool>.from(ref.read(_appliedProvider));
            updated[i] = true;
            ref.read(_appliedProvider.notifier).state = updated;
          }),
        );
      }).toList(),
    );
  }
}

class _OptCard extends StatefulWidget {
  final _Optimisation opt;
  final bool done;
  final VoidCallback onApply;
  const _OptCard(
      {required this.opt, required this.done, required this.onApply});

  @override
  State<_OptCard> createState() => _OptCardState();
}

class _OptCardState extends State<_OptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final opt = widget.opt;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.done
            ? const Color(0xFF10B981).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: widget.done
              ? const Color(0xFF10B981).withOpacity(0.35)
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: opt.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(opt.area,
                    style: TextStyle(
                        color: opt.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(opt.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              // Before → After
              Row(children: [
                Text(opt.before,
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 11,
                        fontFamily: 'monospace')),
                const Text(' → ',
                    style: TextStyle(
                        color: Color(0xFF4B5563), fontSize: 11)),
                Text(opt.after,
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ]),
              const SizedBox(width: ZapSpacing.sm),
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
                    Text(opt.desc,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            height: 1.5)),
                    const SizedBox(height: ZapSpacing.md),
                    _diffBlock(opt.codeFile, opt.codeBefore, opt.codeAfter),
                    const SizedBox(height: ZapSpacing.md),
                    widget.done
                        ? _statusChip(Icons.check_circle_rounded,
                            const Color(0xFF10B981), 'Applied ✅')
                        : _actionButton(
                            label: 'Apply optimisation',
                            icon: Icons.bolt_rounded,
                            color: opt.color,
                            onTap: widget.onApply),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ── Metrics summary ────────────────────────────────────────────────────────────
class _MetricsSummary extends StatelessWidget {
  final List<bool> applied;
  const _MetricsSummary({required this.applied});

  @override
  Widget build(BuildContext context) {
    final coldFixed    = applied[0];
    final battFixed    = applied[1] || applied[2];
    final coldAfter    = coldFixed   ? '1.8s' : '5.2s';
    final battAfter    = battFixed   ? '6.0%' : '20.0%';

    return Row(children: [
      Expanded(child: _MetricCard(
        label: 'Cold start',
        before: '5.2s', after: coldAfter,
        icon: Icons.timer_rounded,
        target: '< 2s',
        achieved: coldFixed,
      )),
      const SizedBox(width: ZapSpacing.sm),
      Expanded(child: _MetricCard(
        label: 'Battery/hr',
        before: '20%', after: battAfter,
        icon: Icons.battery_charging_full_rounded,
        target: '< 7%',
        achieved: battFixed,
      )),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  final String label, before, after, target;
  final IconData icon;
  final bool achieved;
  const _MetricCard({
    required this.label,
    required this.before,
    required this.after,
    required this.icon,
    required this.target,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        achieved ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(after,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        Text(
          achieved ? '✅ Target $target' : 'Before: $before',
          style: TextStyle(
              color: achieved
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6B7280),
              fontSize: 10),
        ),
      ]),
    );
  }
}

// ── Completion card ────────────────────────────────────────────────────────────
class _CompletionCard extends StatelessWidget {
  const _CompletionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(children: [
        const Icon(Icons.speed_rounded,
            color: Color(0xFF10B981), size: 44),
        const SizedBox(height: ZapSpacing.md),
        const Text('Day 129 Complete!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Cold start: 5.2s → 1.8s\nBattery: 20%/hr → 6%/hr',
          style: TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 13, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
          alignment: WrapAlignment.center,
          children: const [
            _Chip('DB deferred',           Color(0xFF3B82F6)),
            _Chip('TFLite deferred',       Color(0xFF8B5CF6)),
            _Chip('GPS adaptive',          Color(0xFF10B981)),
            _Chip('Audio batched 500ms',   Color(0xFFF59E0B)),
          ],
        ),
      ]),
    );
  }
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
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

// ── Next card ──────────────────────────────────────────────────────────────────
class _NextCard extends StatelessWidget {
  const _NextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _row(const Color(0xFF8B5CF6), 'Day 130',
            'Memory optimisation — 195 MB → < 120 MB · image cache '
            'limits · lazy-load non-critical screens · low-RAM < 2 GB stability'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF3B82F6), 'Days 131-132',
            'Fix memory leaks — dispose location listeners, '
            'cap DB connections, clear old GPS trace buffers'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF10B981), 'Days 133-134',
            'Simplify onboarding — 7 steps → 4, '
            'clearer permission rationale, target < 2 min'),
      ]),
    );
  }

  Widget _row(Color color, String days, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
        ]),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _metricBox(String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: ZapSpacing.sm, horizontal: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ),
    );

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

Widget _diffBlock(String filename, String before, String after) =>
    Container(
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
        ...before.split('\n').map((l) => Text(
              '- $l',
              style: const TextStyle(
                  color: Color(0xFFFF7B72),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.5),
            )),
        const SizedBox(height: 4),
        ...after.split('\n').map((l) => Text(
              '+ $l',
              style: const TextStyle(
                  color: Color(0xFF7EE787),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.5),
            )),
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
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 14),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
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
