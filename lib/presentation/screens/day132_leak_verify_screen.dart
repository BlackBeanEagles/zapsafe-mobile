/// Day 132 — Memory Leak Fixes (Part 2) & Stability Verification
///
/// Second half of the Days 131-132 memory leak cycle.
/// Day 131 fixed: AnimationController, StreamSubscription, Location listener.
/// Day 132 fixes:
///   Leak 4 — Database connections not closed (SQLite / Hive)
///   Leak 5 — Periodic Timer never cancelled
///
/// Then runs a 30-minute stability session to confirm no OOM crash,
/// and ships v0.5.5 bundling all 5 leak fixes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeLeakProvider  = StateProvider<int>((ref) => 0);
final _appliedProvider     = StateProvider<List<bool>>(
  (ref) => List.filled(2, false),
);
final _stabilityProvider   = StateProvider<_StabilityState>(
  (ref) => _StabilityState.idle,
);
final _stabilityMinProvider = StateProvider<int>((ref) => 0);
final _memReadingsProvider  = StateProvider<List<int>>((ref) => []);
final _shipStateProvider    = StateProvider<_ShipState>((ref) => _ShipState.idle);
final _verifyProvider       = StateProvider<List<bool>>(
  (ref) => List.filled(_kVerifyChecks.length, false),
);

enum _StabilityState { idle, running, passed, failed }
enum _ShipState      { idle, building, uploading, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Leak {
  final String id;
  final String title;
  final String service;
  final Color  color;
  final int    leakMbPerMin;
  final String symptom;
  final String rootCause;
  final String fix;
  final String codeFile;
  final String codeBefore;
  final String codeAfter;
  const _Leak({
    required this.id,
    required this.title,
    required this.service,
    required this.color,
    required this.leakMbPerMin,
    required this.symptom,
    required this.rootCause,
    required this.fix,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
  });
}

const _kLeaks = [
  _Leak(
    id: 'L4',
    title: 'SQLite / Hive connections not closed',
    service: 'EvidenceRepository · GpsTraceRepository',
    color: Color(0xFF3B82F6),
    leakMbPerMin: 2,
    symptom: 'Each DB read/write opens a new connection that is never '
        'closed. After 500 operations the connection pool exhausts '
        'memory. Visible as growing native heap in DevTools.',
    rootCause: 'EvidenceRepository calls sqflite.openDatabase() inside '
        'every method without closing the handle. Hive boxes are '
        'opened but LazyBox.close() is never awaited on dispose.',
    fix: 'Use a singleton database instance. Open once in init(), '
        'close in dispose(). For Hive, close the box in the '
        'provider\'s onDispose callback.',
    codeFile: 'evidence_repository.dart',
    codeBefore:
        'class EvidenceRepository {\n'
        '  Future<List<Evidence>> getAll() async {\n'
        '    // ❌ Opens a new DB connection every call\n'
        '    final db = await openDatabase(\'evidence.db\');\n'
        '    final rows = await db.query(\'evidence\');\n'
        '    // ❌ db.close() never called\n'
        '    return rows.map(Evidence.fromMap).toList();\n'
        '  }\n'
        '}',
    codeAfter:
        'class EvidenceRepository {\n'
        '  Database? _db;\n'
        '\n'
        '  Future<void> init() async {\n'
        '    _db = await openDatabase(\'evidence.db\');\n'
        '  }\n'
        '\n'
        '  Future<List<Evidence>> getAll() async {\n'
        '    // ✅ Reuse singleton connection\n'
        '    final rows = await _db!.query(\'evidence\');\n'
        '    return rows.map(Evidence.fromMap).toList();\n'
        '  }\n'
        '\n'
        '  Future<void> dispose() async {\n'
        '    await _db?.close(); // ✅ closes on shutdown\n'
        '    _db = null;\n'
        '  }\n'
        '}',
  ),
  _Leak(
    id: 'L5',
    title: 'Periodic Timer never cancelled',
    service: 'DcsEngine · SosEscalationService · PushPollService',
    color: Color(0xFF10B981),
    leakMbPerMin: 1,
    symptom: 'Each screen navigation that touches DCS or SOS creates '
        'a new periodic timer. After 10 navigations, 10 timers '
        'fire simultaneously — wasting CPU and holding widget refs.',
    rootCause: 'Timer.periodic() returns a Timer object that must be '
        'cancelled via timer.cancel(). Without cancellation the '
        'Dart VM keeps the closure alive even after the owning '
        'object is "gone".',
    fix: 'Store Timer in a nullable field. Cancel in dispose(). '
        'Use ref.onDispose in Riverpod providers. Add a guard: '
        'if (_timer?.isActive == true) return; before creating.',
    codeFile: 'dcs_engine.dart',
    codeBefore:
        'class DcsEngine {\n'
        '  void start() {\n'
        '    // ❌ New timer every call — old one keeps firing\n'
        '    Timer.periodic(Duration(milliseconds: 500), (_) {\n'
        '      _runInference();\n'
        '    });\n'
        '  }\n'
        '  // ❌ No stop() override\n'
        '}',
    codeAfter:
        'class DcsEngine {\n'
        '  Timer? _inferenceTimer;\n'
        '\n'
        '  void start() {\n'
        '    // ✅ Guard: cancel existing before creating new\n'
        '    if (_inferenceTimer?.isActive == true) return;\n'
        '    _inferenceTimer = Timer.periodic(\n'
        '      const Duration(milliseconds: 500), (_) {\n'
        '        _runInference();\n'
        '      });\n'
        '  }\n'
        '\n'
        '  void stop() {\n'
        '    _inferenceTimer?.cancel(); // ✅\n'
        '    _inferenceTimer = null;\n'
        '  }\n'
        '}',
  ),
];

const _kVerifyChecks = [
  'L1 fixed: AnimationController.dispose() in all 4 screens',
  'L2 fixed: StreamSubscription.cancel() in all 4 providers',
  'L3 fixed: GpsService ref-count — stopTracking() called on pop',
  'L4 fixed: Singleton DB — no new connection per query',
  'L5 fixed: Timer.cancel() guard in DcsEngine + 2 services',
  '30-min session: memory stays ≤ 65 MB throughout',
  'Xiaomi Redmi 9 (2 GB): no OOM after 30-min background test',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day132LeakVerifyScreen extends ConsumerWidget {
  const Day132LeakVerifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active     = ref.watch(_activeLeakProvider);
    final applied    = ref.watch(_appliedProvider);
    final stability  = ref.watch(_stabilityProvider);
    final verChecks  = ref.watch(_verifyProvider);
    final shipState  = ref.watch(_shipStateProvider);
    final allFixed   = applied.every((a) => a);
    final allVerified= verChecks.every((c) => c);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 132 · Leak Fixes & Verify'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Day 131 recap
            const _SectionLabel('DAY 131 RECAP  ·  LEAKS ALREADY FIXED'),
            const SizedBox(height: ZapSpacing.md),
            const _Day131Recap(),
            const SizedBox(height: ZapSpacing.xl),

            // Leak selector
            const _SectionLabel('DAY 132  ·  FIX 2 MORE LEAKS'),
            const SizedBox(height: ZapSpacing.md),
            _LeakSelector(active: active, applied: applied),
            const SizedBox(height: ZapSpacing.xl),

            // Leak detail
            _LeakDetail(leak: _kLeaks[active], index: active),
            const SizedBox(height: ZapSpacing.xl),

            // All-leaks summary (after both fixed)
            if (allFixed) ...[
              const _SectionLabel('ALL 5 LEAKS FIXED  ·  TOTAL SAVED'),
              const SizedBox(height: ZapSpacing.md),
              const _AllLeaksSummary(),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // 30-min stability test
            const _SectionLabel('30-MINUTE STABILITY SESSION'),
            const SizedBox(height: ZapSpacing.md),
            _StabilityTest(state: stability, allFixed: allFixed),
            const SizedBox(height: ZapSpacing.xl),

            // Verify checklist
            const _SectionLabel('VERIFICATION CHECKLIST  ·  DAYS 131-132'),
            const SizedBox(height: ZapSpacing.md),
            _VerifyChecklist(checks: verChecks, allDone: allVerified),
            const SizedBox(height: ZapSpacing.xl),

            // Ship
            const _SectionLabel('SHIP  ·  v0.5.5 MEMORY LEAK FIXES'),
            const SizedBox(height: ZapSpacing.md),
            _ShipPanel(allVerified: allVerified, state: shipState),
            const SizedBox(height: ZapSpacing.xl),

            // Next
            const _SectionLabel('NEXT  ·  DAYS 133-134'),
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
          colors: [Color(0xFF041A12), Color(0xFF020D09), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 132', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5.5 Leak Fixes', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'DB & Timer Leaks\n+ Stability Test',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Day 131 plugged 3 leaks (10 MB/min). '
            'Day 132 closes 2 more: SQLite connections opened per-query '
            'and Timer.periodic() never cancelled. '
            'Then run a 30-min stability session to confirm no OOM.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('2',      'More leaks',    Color(0xFF3B82F6)),
            _HStat('3 MB',   'More saved/min',Color(0xFF10B981)),
            _HStat('5 total','All leaks',     Color(0xFF8B5CF6)),
            _HStat('30 min', 'Stability test',Color(0xFFF59E0B)),
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

// ── Day 131 Recap ──────────────────────────────────────────────────────────────
class _Day131Recap extends StatelessWidget {
  const _Day131Recap();

  static const _items = [
    (Color(0xFFEF4444), 'L1', 'AnimationController.dispose()',    '−3 MB/min'),
    (Color(0xFFF97316), 'L2', 'StreamSubscription.cancel()',      '−5 MB/min'),
    (Color(0xFFF59E0B), 'L3', 'GpsService ref-count stopTracking','−2 MB/min'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Column(
        children: _items.asMap().entries.map((e) {
          final i = e.key;
          final (_, id, title, saved) = e.value;
          final isLast = i == _items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(id,
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(saved,
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
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

// ── Leak selector ──────────────────────────────────────────────────────────────
class _LeakSelector extends ConsumerWidget {
  final int active;
  final List<bool> applied;
  const _LeakSelector({required this.active, required this.applied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: _kLeaks.asMap().entries.map((e) {
        final i    = e.key;
        final leak = e.value;
        final isActive = i == active;
        final isDone   = applied[i];

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                ref.read(_activeLeakProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i == 0 ? ZapSpacing.sm : 0),
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
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leak.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        isDone
                            ? '−${leak.leakMbPerMin} MB/min ✅'
                            : '+${leak.leakMbPerMin} MB/min',
                        style: TextStyle(
                            color: isDone
                                ? const Color(0xFF10B981)
                                : leak.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
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
        _SectionLabel('LEAK ${leak.id}  ·  ${leak.service}'),
        const SizedBox(height: ZapSpacing.md),

        // Meta box
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
                  final next = updated.indexWhere((v) => !v);
                  if (next != -1) {
                    ref.read(_activeLeakProvider.notifier).state = next;
                  }
                },
              ),
      ],
    );
  }
}

// ── All Leaks Summary ──────────────────────────────────────────────────────────
class _AllLeaksSummary extends StatelessWidget {
  const _AllLeaksSummary();

  static const _all = [
    (Color(0xFFEF4444), 'L1', 'AnimationController.dispose()',       3),
    (Color(0xFFF97316), 'L2', 'StreamSubscription.cancel()',         5),
    (Color(0xFFF59E0B), 'L3', 'GpsService ref-count',                2),
    (Color(0xFF3B82F6), 'L4', 'Singleton DB connection',             2),
    (Color(0xFF10B981), 'L5', 'Timer.cancel() guard',                1),
  ];

  @override
  Widget build(BuildContext context) {
    const total = 13;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.1),
          const Color(0xFF10B981).withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(children: [
        // Total
        Row(children: [
          const Text('−$total MB/min total',
              style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('All 5 fixed ✅',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Before: OOM at ~30 min  →  After: Stable indefinitely',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.lg),
        // Per-leak chips
        Wrap(
          spacing: ZapSpacing.sm,
          runSpacing: ZapSpacing.sm,
          children: _all.map((item) {
            final (color, id, title, mb) = item;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(id,
                            style: TextStyle(
                                color: color,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)))),
                const SizedBox(width: 5),
                Text('$title  −${mb}MB',
                    style: const TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 11)),
              ]),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Stability Test ─────────────────────────────────────────────────────────────
class _StabilityTest extends ConsumerStatefulWidget {
  final _StabilityState state;
  final bool allFixed;
  const _StabilityTest({required this.state, required this.allFixed});

  @override
  ConsumerState<_StabilityTest> createState() => _StabilityTestState();
}

class _StabilityTestState extends ConsumerState<_StabilityTest> {
  // Simulated memory readings every 2-min interval (15 intervals = 30 min)
  static const _kStableReadings = [
    58, 59, 60, 58, 61, 59, 60, 58, 62, 59, 61, 58, 60, 59, 58
  ];

  Future<void> _runTest() async {
    ref.read(_stabilityProvider.notifier).state = _StabilityState.running;
    ref.read(_memReadingsProvider.notifier).state = [];
    ref.read(_stabilityMinProvider.notifier).state = 0;

    for (int i = 0; i < _kStableReadings.length; i++) {
      await Future.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      ref.read(_stabilityMinProvider.notifier).state = (i + 1) * 2;
      ref.read(_memReadingsProvider.notifier).state =
          _kStableReadings.take(i + 1).toList();
    }

    if (!mounted) return;
    ref.read(_stabilityProvider.notifier).state = _StabilityState.passed;
  }

  @override
  Widget build(BuildContext context) {
    final minutes  = ref.watch(_stabilityMinProvider);
    final readings = ref.watch(_memReadingsProvider);
    final state    = widget.state;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _StabilityState.passed
              ? const Color(0xFF10B981).withOpacity(0.4)
              : state == _StabilityState.failed
                  ? const Color(0xFFEF4444).withOpacity(0.4)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        if (state == _StabilityState.idle) ...[
          _infoBox(
            icon: Icons.science_rounded,
            color: const Color(0xFFF59E0B),
            text: 'Simulates the app running for 30 minutes in background: '
                'navigating screens, triggering SOS, playing audio. '
                'Memory should stay flat at ~58-65 MB with all leaks fixed.',
          ),
          const SizedBox(height: ZapSpacing.lg),
          if (!widget.allFixed)
            _infoBox(
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEF4444),
              text: 'Fix both leaks above before running stability test.',
            )
          else
            _actionButton(
              label: 'Run 30-min stability simulation',
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFF10B981),
              onTap: _runTest,
            ),
        ] else if (state == _StabilityState.running) ...[
          // Live stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$minutes / 30 min',
                style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              Text(
                readings.isNotEmpty ? '${readings.last} MB' : '— MB',
                style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: minutes / 30,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          // Mini chart
          if (readings.isNotEmpty) _MiniChart(readings: readings),
        ] else if (state == _StabilityState.passed) ...[
          // Full result chart
          _MiniChart(readings: _kStableReadings),
          const SizedBox(height: ZapSpacing.lg),
          const Icon(Icons.verified_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('30-min session passed!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Peak RAM: 62 MB  ·  No OOM events  ·  Memory stable',
            style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Crash window before fixes: ~30 min\n'
            'Crash window after fixes: None detected',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () {
              ref.read(_stabilityProvider.notifier).state =
                  _StabilityState.idle;
              ref.read(_memReadingsProvider.notifier).state = [];
              ref.read(_stabilityMinProvider.notifier).state = 0;
            },
            child: const Text('Reset test',
                style: TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12)),
          ),
        ],
      ]),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<int> readings;
  const _MiniChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    const maxMb   = 140.0;
    const oomLine = 120.0;

    return SizedBox(
      height: 80,
      child: Stack(children: [
        // OOM threshold
        Positioned(
          top: (1 - oomLine / maxMb) * 80,
          left: 0, right: 0,
          child: Container(
              height: 1,
              color: const Color(0xFFEF4444).withOpacity(0.4)),
        ),
        // Bars
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: readings.asMap().entries.map((e) {
            final mb  = e.value;
            final h   = (mb / maxMb * 70).clamp(4.0, 70.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.7),
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
    );
  }
}

// ── Verify Checklist ───────────────────────────────────────────────────────────
class _VerifyChecklist extends ConsumerWidget {
  final List<bool> checks;
  final bool allDone;
  const _VerifyChecklist({required this.checks, required this.allDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneCount = checks.where((c) => c).length;
    return Container(
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
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(children: [
            Row(children: [
              Text('$doneCount / ${_kVerifyChecks.length} verified',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                allDone ? '✅ Ready to ship v0.5.5' : 'Tap to verify',
                style: TextStyle(
                    color: allDone
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                    fontSize: 11),
              ),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / _kVerifyChecks.length,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  allDone
                      ? const Color(0xFF10B981)
                      : const Color(0xFF3B82F6),
                ),
                minHeight: 5,
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ...List.generate(_kVerifyChecks.length, (i) {
          final done   = checks[i];
          final isLast = i == _kVerifyChecks.length - 1;
          return GestureDetector(
            onTap: () {
              final updated = List<bool>.from(ref.read(_verifyProvider));
              updated[i] = !updated[i];
              ref.read(_verifyProvider.notifier).state = updated;
            },
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
                    child: Text(_kVerifyChecks[i],
                        style: TextStyle(
                          color: done
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                          fontSize: 12,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
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

// ── Ship Panel ─────────────────────────────────────────────────────────────────
class _ShipPanel extends ConsumerWidget {
  final bool allVerified;
  final _ShipState state;
  const _ShipPanel({required this.allVerified, required this.state});

  static const _kStates = [
    _ShipState.idle, _ShipState.building,
    _ShipState.uploading, _ShipState.done,
  ];
  static const _kLabels = [
    '', 'Building v0.5.5 release…',
    'Uploading to TestFlight + Play…', 'v0.5.5 live!',
  ];
  static const _kColors = [
    Color(0xFF10B981), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFF10B981),
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
        _codeNote('changelog',
            'v0.5.5 — Memory Leak Fixes (Days 131-132)\n'
            '⚡ L1: AnimationController.dispose() in 4 screens\n'
            '⚡ L2: StreamSubscription.cancel() in 4 providers\n'
            '⚡ L3: GpsService ref-counting — stop on last consumer\n'
            '⚡ L4: Singleton SQLite DB — no per-query open/close\n'
            '⚡ L5: Timer.cancel() guard in DcsEngine + 2 services\n'
            'Result: −13 MB/min leak · OOM crash eliminated'),
        const SizedBox(height: ZapSpacing.md),
        if (state == _ShipState.done) ...[
          const Icon(Icons.rocket_launch_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.5 shipped!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'All 5 memory leaks fixed.\nDays 131-132 complete.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ] else if (state != _ShipState.idle)
          ...List.generate(2, (i) {
            final idx     = _kStates.indexOf(state);
            final isDone  = i + 1 < idx;
            final isActive= i + 1 == idx;
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
                                : const Color(0xFF2A2A2A)),
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
                            : FontWeight.w400)),
              ]),
            );
          })
        else ...[
          if (!allVerified)
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              margin: const EdgeInsets.only(bottom: ZapSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 14),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text('Complete all 7 verify checks first',
                      style: TextStyle(
                          color: Color(0xFFF59E0B), fontSize: 11)),
                ),
              ]),
            ),
          GestureDetector(
            onTap: allVerified
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
                gradient: allVerified
                    ? const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)])
                    : null,
                color: allVerified ? null : const Color(0xFF111111),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: allVerified
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
                      ]
                    : null,
                border: allVerified
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: allVerified
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 18),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    allVerified
                        ? 'Ship v0.5.5 — Memory leak fixes'
                        : 'Complete verification first',
                    style: TextStyle(
                      color: allVerified
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
        ],
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
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _row(const Color(0xFF3B82F6), 'Days 133-134',
            'Simplify onboarding — 7 steps → 4, '
            'clearer permission rationale, target < 2 min total'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF8B5CF6), 'Day 135',
            'Bundle release v0.5.6 — all fixes from '
            'Days 121-134 packaged as the complete beta iteration'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFFF59E0B), 'Days 136-137',
            'Second feedback round — did the fixes land? '
            'Check Sentry, re-run false positive test, measure retention'),
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
