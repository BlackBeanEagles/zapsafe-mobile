/// Day 131 — Fix Memory Leaks (Part 1)
///
/// Beta devices crash after ~30 minutes in background. DevTools memory
/// timeline shows a slow upward slope — classic leak pattern.
/// Three root causes identified from heap analysis:
///
///   Leak 1 — AnimationController never disposed
///             (SOS pulse ring + protection score ring)
///   Leak 2 — StreamSubscription never cancelled
///             (GPS stream + audio stream + WebSocket)
///   Leak 3 — Location listener persists after screen pop
///             (GpsService._locationStream left open)
///
/// Day 132 covers: DB connection leaks + Timer leaks + verification.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeLeakProvider  = StateProvider<int>((ref) => 0);
final _appliedProvider     = StateProvider<List<bool>>(
  (ref) => List.filled(3, false),
);
final _memSimProvider      = StateProvider<_MemSimState>((ref) => _MemSimState.idle);
final _timelineProvider    = StateProvider<List<int>>(
  (ref) => const [45, 48, 52, 57, 63, 70, 78, 87, 97, 108, 119, 131],
);

enum _MemSimState { idle, leaked, fixed }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Leak {
  final String id;
  final String title;
  final String widget;
  final Color  color;
  final int    leakMbPerMin;
  final String symptom;
  final String rootCause;
  final String fix;
  final String codeFile;
  final String codeBefore;
  final String codeAfter;
  final List<String> affectedScreens;
  const _Leak({
    required this.id,
    required this.title,
    required this.widget,
    required this.color,
    required this.leakMbPerMin,
    required this.symptom,
    required this.rootCause,
    required this.fix,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
    required this.affectedScreens,
  });
}

const _kLeaks = [
  _Leak(
    id: 'L1',
    title: 'AnimationController not disposed',
    widget: 'SosActiveScreen · DashboardScreen',
    color: Color(0xFFEF4444),
    leakMbPerMin: 3,
    symptom: 'Heap grows ~3 MB/min when navigating to/from SOS or '
        'Dashboard. Each new screen push creates a new controller '
        'that is never released.',
    rootCause: 'AnimationController.repeat() keeps the vsync ticker '
        'alive. If dispose() is never called, the Ticker keeps a '
        'reference to the widget tree — preventing garbage collection.',
    fix: 'Override dispose() in every StatefulWidget that creates an '
        'AnimationController. Call controller.dispose() before '
        'super.dispose().',
    codeFile: 'sos_active_screen.dart',
    codeBefore:
        'class _SosActiveState extends State<SosActiveScreen>\n'
        '    with SingleTickerProviderStateMixin {\n'
        '\n'
        '  late final AnimationController _pulse;\n'
        '\n'
        '  @override\n'
        '  void initState() {\n'
        '    super.initState();\n'
        '    _pulse = AnimationController(\n'
        '      vsync: this,\n'
        '      duration: const Duration(milliseconds: 800),\n'
        '    )..repeat(reverse: true);\n'
        '  }\n'
        '  // ❌ No dispose() override\n'
        '}',
    codeAfter:
        'class _SosActiveState extends State<SosActiveScreen>\n'
        '    with SingleTickerProviderStateMixin {\n'
        '\n'
        '  late final AnimationController _pulse;\n'
        '\n'
        '  @override\n'
        '  void initState() {\n'
        '    super.initState();\n'
        '    _pulse = AnimationController(\n'
        '      vsync: this,\n'
        '      duration: const Duration(milliseconds: 800),\n'
        '    )..repeat(reverse: true);\n'
        '  }\n'
        '\n'
        '  @override\n'
        '  void dispose() {\n'
        '    _pulse.dispose(); // ✅ releases Ticker\n'
        '    super.dispose();\n'
        '  }\n'
        '}',
    affectedScreens: [
      'SosActiveScreen — pulse ring',
      'DashboardScreen — score ring',
      'AlertPendingScreen — countdown ring',
      'Day50MotionValidationScreen — spark line',
    ],
  ),
  _Leak(
    id: 'L2',
    title: 'StreamSubscription never cancelled',
    widget: 'GpsService · AudioCaptureService · LiveChatScreen',
    color: Color(0xFFF97316),
    leakMbPerMin: 5,
    symptom: 'Each screen pop leaves a dangling StreamSubscription. '
        'GPS stream accumulates subscribers — after 20 nav ops '
        'there are 20 parallel GPS listeners all firing.',
    rootCause: 'Riverpod providers that subscribe to platform streams '
        '(geolocator, microphone, WebSocket) do not cancel the '
        'subscription when their ref is invalidated.',
    fix: 'Store StreamSubscription in a local variable and call '
        'subscription.cancel() in the provider\'s onDispose callback '
        'or widget dispose().',
    codeFile: 'gps_provider.dart',
    codeBefore:
        'final gpsProvider = StreamProvider<Position>((ref) async* {\n'
        '  final stream = Geolocator.getPositionStream();\n'
        '  // ❌ Never cancelled when provider disposed\n'
        '  await for (final pos in stream) {\n'
        '    yield pos;\n'
        '  }\n'
        '});',
    codeAfter:
        'final gpsProvider = StreamProvider<Position>((ref) async* {\n'
        '  final sub = Geolocator.getPositionStream();\n'
        '\n'
        '  // ✅ Cancel on provider disposal\n'
        '  StreamSubscription<Position>? subscription;\n'
        '  ref.onDispose(() => subscription?.cancel());\n'
        '\n'
        '  subscription = sub.listen(null);\n'
        '  await for (final pos in sub) {\n'
        '    yield pos;\n'
        '  }\n'
        '});',
    affectedScreens: [
      'GpsService — location stream',
      'AudioCaptureService — mic stream',
      'LiveChatScreen — WebSocket stream',
      'DcsEngine — fusion score stream',
    ],
  ),
  _Leak(
    id: 'L3',
    title: 'Location listener persists after screen pop',
    widget: 'GpsService · BackgroundEngine',
    color: Color(0xFFF59E0B),
    leakMbPerMin: 2,
    symptom: 'GpsService._locationManager never calls stopUpdating '
        'when the screen is dismissed. GPS runs continuously even '
        'when no screen needs location data.',
    rootCause: 'GpsService is a singleton that starts on first use '
        'but has no mechanism to stop when all consumers are gone. '
        'The platform location manager keeps a strong reference.',
    fix: 'Add reference counting to GpsService. startTracking() '
        'increments a counter; stopTracking() decrements. Only '
        'call stopUpdatingLocation() when counter reaches 0.',
    codeFile: 'gps_service.dart',
    codeBefore:
        'class GpsService {\n'
        '  static final instance = GpsService._();\n'
        '  StreamSubscription? _sub;\n'
        '\n'
        '  void start() {\n'
        '    _sub = Geolocator.getPositionStream().listen(_onPos);\n'
        '  }\n'
        '\n'
        '  // ❌ stop() never called from screens\n'
        '  void stop() => _sub?.cancel();\n'
        '}',
    codeAfter:
        'class GpsService {\n'
        '  static final instance = GpsService._();\n'
        '  StreamSubscription? _sub;\n'
        '  int _consumers = 0; // ✅ reference count\n'
        '\n'
        '  void startTracking() {\n'
        '    _consumers++;\n'
        '    if (_consumers == 1) {\n'
        '      _sub = Geolocator.getPositionStream().listen(_onPos);\n'
        '    }\n'
        '  }\n'
        '\n'
        '  void stopTracking() {\n'
        '    _consumers = (_consumers - 1).clamp(0, 9999);\n'
        '    if (_consumers == 0) _sub?.cancel();\n'
        '  }\n'
        '}',
    affectedScreens: [
      'TrustedCircleScreen — live location',
      'JourneyModeScreen — route tracking',
      'SosActiveScreen — evidence GPS',
      'SafetyMapScreen — heatmap updates',
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day131MemoryLeaksScreen extends ConsumerWidget {
  const Day131MemoryLeaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active  = ref.watch(_activeLeakProvider);
    final applied = ref.watch(_appliedProvider);
    final allDone = applied.every((a) => a);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 131 · Memory Leaks'),
        elevation: 0,
        actions: [
          if (allDone)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Text('All leaks fixed ✅',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
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

            // Memory timeline
            const _SectionLabel('MEMORY TIMELINE  ·  30-MINUTE SESSION'),
            const SizedBox(height: ZapSpacing.md),
            const _MemoryTimeline(),
            const SizedBox(height: ZapSpacing.xl),

            // Leak selector
            const _SectionLabel('SELECT LEAK TO FIX'),
            const SizedBox(height: ZapSpacing.md),
            _LeakSelector(active: active, applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            // Leak detail
            _LeakDetail(leak: _kLeaks[active], index: active),
            const SizedBox(height: ZapSpacing.xl),

            // Progress
            const _SectionLabel('FIX PROGRESS  ·  DAY 131'),
            const SizedBox(height: ZapSpacing.md),
            _FixProgress(applied: applied),
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
          colors: [Color(0xFF1A0A0A), Color(0xFF0D0505), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 131', const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Memory Leaks', const Color(0xFFF97316)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Fix Memory\nLeaks',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'App crashes after ~30 min in background. '
            'DevTools memory timeline shows a slow upward slope — '
            'classic leak pattern. 3 root causes: AnimationControllers '
            'never disposed, streams never cancelled, location never stopped.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('3',      'Leak types',     Color(0xFFEF4444)),
            _HStat('10 MB',  'Leak/min',       Color(0xFFF97316)),
            _HStat('30 min', 'Crash window',   Color(0xFFF59E0B)),
            _HStat('OOM',    'Root cause',     Color(0xFF8B5CF6)),
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
                  fontSize: 15,
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

// ── Memory Timeline ────────────────────────────────────────────────────────────
class _MemoryTimeline extends ConsumerWidget {
  const _MemoryTimeline();

  // Memory values after fix: stays flat ~58 MB
  static const _kFixedValues = [
    58, 59, 58, 60, 59, 58, 61, 59, 58, 60, 59, 58
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simState = ref.watch(_memSimProvider);
    final leaked   = ref.watch(_timelineProvider);
    final values   = simState == _MemSimState.fixed
        ? _kFixedValues
        : leaked;

    const maxMb   = 140.0;
    const oomLine = 120.0;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Heap memory over 30 min',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11)),
            Row(children: [
              GestureDetector(
                onTap: () => ref
                    .read(_memSimProvider.notifier)
                    .state = _MemSimState.leaked,
                child: _simChip('With leaks',
                    simState == _MemSimState.leaked ||
                        simState == _MemSimState.idle,
                    const Color(0xFFEF4444)),
              ),
              const SizedBox(width: ZapSpacing.sm),
              GestureDetector(
                onTap: () => ref
                    .read(_memSimProvider.notifier)
                    .state = _MemSimState.fixed,
                child: _simChip('After fix',
                    simState == _MemSimState.fixed,
                    const Color(0xFF10B981)),
              ),
            ]),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Chart
        SizedBox(
          height: 120,
          child: Stack(children: [
            // OOM line
            Positioned(
              top: (1 - oomLine / maxMb) * 120,
              left: 0, right: 0,
              child: Row(children: [
                Container(
                    height: 1,
                    width: 30,
                    color: const Color(0xFFEF4444).withOpacity(0.5)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  child: const Text('OOM threshold 120 MB',
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 8)),
                ),
                Expanded(
                  child: Container(
                      height: 1,
                      color: const Color(0xFFEF4444)
                          .withOpacity(0.5)),
                ),
              ]),
            ),
            // Bars
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values.asMap().entries.map((e) {
                final i   = e.key;
                final mb  = e.value;
                final h   = (mb / maxMb * 110).clamp(4.0, 110.0);
                final col = simState == _MemSimState.fixed
                    ? const Color(0xFF10B981)
                    : mb >= 120
                        ? const Color(0xFFEF4444)
                        : mb >= 90
                            ? const Color(0xFFF97316)
                            : const Color(0xFF8B5CF6);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$mb',
                            style: TextStyle(
                                color: col,
                                fontSize: 7,
                                fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration:
                              Duration(milliseconds: 300 + i * 40),
                          height: h,
                          decoration: BoxDecoration(
                            color: col.withOpacity(0.7),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.sm),
        // X labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0 min', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
            Text('15 min', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
            Text('30 min', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        // Interpretation
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: simState == _MemSimState.fixed
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFFEF4444).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: Text(
            simState == _MemSimState.fixed
                ? '✅ Memory stable at ~58 MB — leaks eliminated'
                : '❌ Memory grows 10 MB/min → OOM crash at ~131 MB '
                    'after 30 min',
            style: TextStyle(
              color: simState == _MemSimState.fixed
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              fontSize: 12,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _simChip(String label, bool active, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? color.withOpacity(0.5)
                  : const Color(0xFF2A2A2A)),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : const Color(0xFF6B7280),
                fontSize: 10,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400)),
      );
}

// ── Leak selector ──────────────────────────────────────────────────────────────
class _LeakSelector extends ConsumerWidget {
  final int active;
  final List<bool> applied;
  const _LeakSelector({required this.active, required this.applied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: _kLeaks.asMap().entries.map((e) {
        final i    = e.key;
        final leak = e.value;
        final isActive = i == active;
        final isDone   = applied[i];

        return GestureDetector(
          onTap: () =>
              ref.read(_activeLeakProvider.notifier).state = i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: isActive
                  ? leak.color.withOpacity(0.08)
                  : const Color(0xFF1A1A1A),
              borderRadius:
                  BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: isActive
                    ? leak.color.withOpacity(0.45)
                    : const Color(0xFF2A2A2A),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(children: [
              // Badge
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : leak.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    isDone ? '✓' : leak.id,
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : leak.color,
                      fontSize: isDone ? 16 : 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leak.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(leak.widget,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10)),
                  ],
                ),
              ),
              // Leak rate + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${leak.leakMbPerMin} MB/min',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : leak.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: const Color(0xFF10B981),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isDone ? 'Fixed' : 'Open',
                      style: TextStyle(
                          color: isDone
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── Leak Detail ────────────────────────────────────────────────────────────────
class _LeakDetail extends ConsumerWidget {
  final _Leak leak;
  final int   index;
  const _LeakDetail({required this.leak, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_appliedProvider);
    final isDone  = applied[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('LEAK ${leak.id}  ·  DETAIL'),
        const SizedBox(height: ZapSpacing.md),

        // Symptom + cause + fix
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _metaRow(Icons.trending_up_rounded, const Color(0xFFEF4444),
                'Symptom', leak.symptom),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _metaRow(Icons.search_rounded, const Color(0xFFF97316),
                'Root cause', leak.rootCause),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _metaRow(Icons.build_rounded, const Color(0xFF10B981),
                'Fix', leak.fix),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Affected screens
        _SectionLabel('AFFECTED SCREENS  ·  ${leak.affectedScreens.length}'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: leak.affectedScreens.asMap().entries.map((e) {
              final i     = e.key;
              final screen= e.value;
              final isLast= i == leak.affectedScreens.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.phone_android_rounded,
                        color: leak.color, size: 14),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(screen,
                        style: const TextStyle(
                            color: Color(0xFFD1D5DB), fontSize: 12)),
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Code diff
        _SectionLabel('CODE FIX  ·  ${leak.codeFile}'),
        const SizedBox(height: ZapSpacing.md),
        _diffBlock(leak.codeFile, leak.codeBefore, leak.codeAfter),
        const SizedBox(height: ZapSpacing.lg),

        // Apply button
        isDone
            ? _statusChip(Icons.check_circle_rounded,
                const Color(0xFF10B981), 'Leak ${leak.id} fixed ✅')
            : _actionButton(
                label: 'Apply fix for ${leak.id}',
                icon: Icons.build_rounded,
                color: leak.color,
                onTap: () async {
                  await Future.delayed(
                      const Duration(milliseconds: 600));
                  if (!context.mounted) return;
                  final updated = List<bool>.from(
                      ref.read(_appliedProvider));
                  updated[index] = true;
                  ref.read(_appliedProvider.notifier).state = updated;

                  // Advance selector
                  final next = updated.indexWhere((v) => !v);
                  if (next != -1) {
                    ref.read(_activeLeakProvider.notifier).state = next;
                  }
                  // Update memory timeline to show fixed state
                  // if all done
                  if (updated.every((v) => v)) {
                    ref.read(_memSimProvider.notifier).state =
                        _MemSimState.fixed;
                  }
                },
              ),
      ],
    );
  }
}

// ── Fix Progress ───────────────────────────────────────────────────────────────
class _FixProgress extends StatelessWidget {
  final List<bool> applied;
  const _FixProgress({required this.applied});

  @override
  Widget build(BuildContext context) {
    final doneCount  = applied.where((a) => a).length;
    final allDone    = doneCount == 3;
    final totalFixed = _kLeaks
        .asMap()
        .entries
        .where((e) => applied[e.key])
        .fold(0, (s, e) => s + e.value.leakMbPerMin);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: allDone
            ? const Color(0xFF10B981).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: allDone
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$doneCount / 3 leaks fixed',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  allDone
                      ? 'Memory stable — no more OOM crashes'
                      : 'Fix remaining leaks above',
                  style: TextStyle(
                      color: allDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '−$totalFixed MB/min',
              style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            const Text('leak rate eliminated',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9)),
          ]),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: doneCount / 3,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              allDone ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kLeaks.asMap().entries.map((e) {
          final i    = e.key;
          final leak = e.value;
          final done = applied[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done
                    ? const Color(0xFF10B981)
                    : const Color(0xFF4B5563),
                size: 16,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: leak.color, shape: BoxShape.circle)),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  '${leak.id}: ${leak.title}',
                  style: TextStyle(
                    color:
                        done ? const Color(0xFF6B7280) : Colors.white,
                    fontSize: 12,
                    decoration:
                        done ? TextDecoration.lineThrough : null,
                    decorationColor: const Color(0xFF6B7280),
                  ),
                ),
              ),
              Text(
                done
                    ? '−${leak.leakMbPerMin} MB/min ✅'
                    : '+${leak.leakMbPerMin} MB/min',
                style: TextStyle(
                    color: done
                        ? const Color(0xFF10B981)
                        : leak.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          );
        }),
        if (allDone) ...[
          const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
          const Row(children: [
            Icon(Icons.arrow_forward_rounded,
                color: Color(0xFFEF4444), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Day 132: Fix DB connection leaks + Timer leaks + '
                'verify 30-min session stability',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _metaRow(IconData icon, Color color, String label, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: ZapSpacing.sm),
      Text('$label: ',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
      ),
    ]);

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
        ...before.split('\n').map((l) => Text('- $l',
            style: const TextStyle(
                color: Color(0xFFFF7B72),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5))),
        const SizedBox(height: ZapSpacing.xs),
        ...after.split('\n').map((l) => Text('+ $l',
            style: const TextStyle(
                color: Color(0xFF7EE787),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5))),
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
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
