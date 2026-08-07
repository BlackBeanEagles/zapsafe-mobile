/// Day 130 — Memory Optimisation & Lazy Loading
///
/// Second half of the Days 129-130 performance cycle.
/// Day 129 fixed cold start (5.2s → 1.8s) and battery (20% → 6%/hr).
/// Day 130 tackles:
///   1. Memory — 195 MB peak → < 120 MB target
///      • Image cache unbounded → cap to 50 MB / 100 entries
///      • GPS trace buffer grows forever → rolling 500-entry window
///      • Old Sentry breadcrumbs accumulate → purge after 24h
///   2. Lazy loading — 130+ screens loaded at startup → load on demand
///   3. Low-RAM stability — devices < 2 GB crash under load
///   4. Ship v0.5.4 performance bundle (Days 129 + 130)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _memProfileProvider   = StateProvider<_MemState>((ref) => _MemState.idle);
final _appliedProvider      = StateProvider<List<bool>>(
  (ref) => List.filled(_kMemFixes.length, false),
);
final _lazyAppliedProvider  = StateProvider<List<bool>>(
  (ref) => List.filled(_kLazyScreens.length, false),
);
final _shipStateProvider    = StateProvider<_ShipState>((ref) => _ShipState.idle);
final _verifyProvider       = StateProvider<List<bool>>(
  (ref) => List.filled(_kVerifyChecks.length, false),
);

enum _MemState  { idle, profiling, done }
enum _ShipState { idle, building, uploading, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _MemoryComponent {
  final String name;
  final int    beforeMb;
  final int    afterMb;
  final Color  color;
  final String cause;
  const _MemoryComponent({
    required this.name,
    required this.beforeMb,
    required this.afterMb,
    required this.color,
    required this.cause,
  });
}

const _kMemComponents = [
  _MemoryComponent(
    name: 'Image cache',
    beforeMb: 68, afterMb: 12,
    color: Color(0xFFEF4444),
    cause: 'No size limit — grows indefinitely with navigation',
  ),
  _MemoryComponent(
    name: 'GPS trace buffer',
    beforeMb: 44, afterMb: 4,
    color: Color(0xFFF97316),
    cause: 'Stores every GPS point since launch — never pruned',
  ),
  _MemoryComponent(
    name: 'TFLite tensor arena',
    beforeMb: 38, afterMb: 22,
    color: Color(0xFFF59E0B),
    cause: 'INT8 models still allocate oversized arenas',
  ),
  _MemoryComponent(
    name: 'Sentry breadcrumbs',
    beforeMb: 22, afterMb: 3,
    color: Color(0xFF8B5CF6),
    cause: 'Breadcrumb log grows without bound — not purged',
  ),
  _MemoryComponent(
    name: 'Dart heap (widgets)',
    beforeMb: 14, afterMb: 11,
    color: Color(0xFF3B82F6),
    cause: 'Minor leaks from un-disposed animation controllers',
  ),
  _MemoryComponent(
    name: 'Native / other',
    beforeMb: 9,  afterMb: 8,
    color: Color(0xFF9CA3AF),
    cause: 'Platform-level allocation — minimal reduction possible',
  ),
];

class _MemFix {
  final String title;
  final String area;
  final Color  color;
  final int    savedMb;
  final String desc;
  final String codeFile;
  final String codeBefore;
  final String codeAfter;
  const _MemFix({
    required this.title,
    required this.area,
    required this.color,
    required this.savedMb,
    required this.desc,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
  });
}

const _kMemFixes = [
  _MemFix(
    title: 'Cap image cache to 50 MB / 100 entries',
    area: 'Image cache',
    color: Color(0xFFEF4444),
    savedMb: 56,
    desc: 'Flutter\'s default PaintingBinding image cache has no size limit. '
        'After navigating 20+ screens with avatars/maps the cache hits 68 MB. '
        'Cap at 50 MB and 100 image entries.',
    codeFile: 'main.dart',
    codeBefore:
        '// No cache limit configured\n'
        'runApp(ProviderScope(child: App()));',
    codeAfter:
        'PaintingBinding.instance.imageCache\n'
        '  ..maximumSize      = 100   // max entries\n'
        '  ..maximumSizeBytes = 50 << 20; // 50 MB\n'
        'runApp(ProviderScope(child: App()));',
  ),
  _MemFix(
    title: 'Rolling GPS trace buffer (500 entries max)',
    area: 'GPS buffer',
    color: Color(0xFFF97316),
    savedMb: 40,
    desc: 'GpsService._buffer is a plain List<LatLng> that appends every '
        'GPS fix since app launch. After 8 hours that\'s ~5,760 entries '
        'at ~8 bytes each = 46 MB. Cap at 500 and drop oldest.',
    codeFile: 'gps_service.dart',
    codeBefore:
        'final _buffer = <LatLng>[];\n'
        '\n'
        'void _onPosition(Position pos) {\n'
        '  _buffer.add(LatLng(pos.latitude, pos.longitude));\n'
        '}',
    codeAfter:
        'final _buffer = Queue<LatLng>();\n'
        'static const _kMaxBuffer = 500;\n'
        '\n'
        'void _onPosition(Position pos) {\n'
        '  _buffer.addLast(LatLng(pos.latitude, pos.longitude));\n'
        '  if (_buffer.length > _kMaxBuffer) _buffer.removeFirst();\n'
        '}',
  ),
  _MemFix(
    title: 'Purge Sentry breadcrumbs older than 24h',
    area: 'Sentry',
    color: Color(0xFF8B5CF6),
    savedMb: 19,
    desc: 'Sentry breadcrumbs accumulate in memory — after 3 days of beta '
        'testing the in-memory log exceeds 22 MB. Purge on app resume '
        'using Sentry.configureScope.',
    codeFile: 'sentry_service.dart',
    codeBefore:
        '// No breadcrumb cleanup\n'
        'await SentryFlutter.init((options) {\n'
        '  options.dsn = _kDsn;\n'
        '});',
    codeAfter:
        'await SentryFlutter.init((options) {\n'
        '  options.dsn             = _kDsn;\n'
        '  options.maxBreadcrumbs  = 50;  // was unlimited\n'
        '});\n'
        '// On app resume, drop stale breadcrumbs\n'
        'Sentry.configureScope((scope) {\n'
        '  scope.clearBreadcrumbs();\n'
        '});',
  ),
];

class _LazyScreen {
  final String name;
  final String route;
  final int    estimatedKb;
  final bool   critical;
  const _LazyScreen(this.name, this.route, this.estimatedKb, this.critical);
}

const _kLazyScreens = [
  _LazyScreen('Dashboard (SOS)',     '/dashboard',      32,  true),
  _LazyScreen('ALERT_PENDING',       '/sos/pending',    18,  true),
  _LazyScreen('Auth / OTP',          '/auth/phone',     12,  true),
  _LazyScreen('Analytics dashboard', '/analytics',      96,  false),
  _LazyScreen('Evidence vault',      '/vault',          88,  false),
  _LazyScreen('Gamification',        '/gamification',   74,  false),
  _LazyScreen('Safety map',          '/map',            112, false),
  _LazyScreen('Settings (all)',      '/settings',       68,  false),
  _LazyScreen('Premium screens',     '/premium',        54,  false),
  _LazyScreen('Help / support',      '/help',           32,  false),
];

const _kVerifyChecks = [
  'Memory peak < 120 MB on Pixel 6 (measured in DevTools)',
  'Image cache hits 50 MB limit and evicts correctly',
  'GPS trace buffer stays ≤ 500 entries after 8h session',
  'Sentry breadcrumbs capped at 50 in memory',
  'Cold start still ≤ 2s with lazy loading applied',
  'Non-critical routes load < 300ms on first tap',
  'Xiaomi Redmi 9 (2 GB) stable for 30 min — no OOM',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day130MemoryScreen extends ConsumerWidget {
  const Day130MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab      = ref.watch(_activeTabProvider);
    final applied  = ref.watch(_appliedProvider);
    final lazyApp  = ref.watch(_lazyAppliedProvider);
    final verChecks = ref.watch(_verifyProvider);
    final shipState = ref.watch(_shipStateProvider);
    final allVerified = verChecks.every((c) => c);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 130 · Memory & Lazy Load'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) _MemoryTab(applied: applied),
            if (tab == 1) _LazyLoadTab(lazyApplied: lazyApp),
            if (tab == 2) const _LowRamTab(),
            const SizedBox(height: ZapSpacing.xl),

            // Verify + ship
            const _SectionLabel('VERIFICATION  ·  DAYS 129-130'),
            const SizedBox(height: ZapSpacing.md),
            _VerifyChecklist(checks: verChecks, allDone: allVerified),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SHIP  ·  v0.5.4 PERFORMANCE BUNDLE'),
            const SizedBox(height: ZapSpacing.md),
            _ShipPanel(allVerified: allVerified, state: shipState),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('NEXT  ·  DAYS 131-132'),
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
          colors: [Color(0xFF0F0A1A), Color(0xFF070510), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 130', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5.4 Perf Bundle', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Memory &\nLazy Loading',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Peak RAM is 195 MB — crashing low-end phones. '
            'Image cache, GPS buffer, and Sentry logs are the main '
            'offenders. Also lazy-loading 130+ screens to save '
            'startup memory and keep first frame under 2s.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('195 MB', 'Peak RAM',     Color(0xFFEF4444)),
            _HStat('→ 58 MB', 'Target',     Color(0xFF10B981)),
            _HStat('130+',   'Screens',     Color(0xFFF59E0B)),
            _HStat('→ lazy', 'Load on demand', Color(0xFF3B82F6)),
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
                  fontSize: 13,
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
      (Icons.memory_rounded,          Color(0xFF8B5CF6), 'Memory'),
      (Icons.layers_rounded,          Color(0xFF3B82F6), 'Lazy Load'),
      (Icons.phone_android_rounded,   Color(0xFFF59E0B), 'Low RAM'),
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
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive
                            ? color
                            : const Color(0xFF6B7280),
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

// ── Memory Tab ─────────────────────────────────────────────────────────────────
class _MemoryTab extends ConsumerWidget {
  final List<bool> applied;
  const _MemoryTab({required this.applied});

  int get _beforeTotal =>
      _kMemComponents.fold(0, (s, c) => s + c.beforeMb);

  int get _afterTotal {
    int saved = 0;
    for (int i = 0; i < _kMemFixes.length; i++) {
      if (i < applied.length && applied[i]) {
        saved += _kMemFixes[i].savedMb;
      }
    }
    return _beforeTotal - saved;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memState = ref.watch(_memProfileProvider);
    final after    = _afterTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.memory_rounded,
          color: const Color(0xFFEF4444),
          text: 'Beta metrics: peak heap 195 MB on a Pixel 6 '
              '(6 GB RAM device). On Xiaomi Redmi 9 (2 GB), OOM '
              'kills the app after 25 min. Image cache and GPS '
              'trace buffer are the biggest leaks.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Profiler
        const _SectionLabel('MEMORY PROFILER  ·  FLUTTER DEVTOOLS'),
        const SizedBox(height: ZapSpacing.md),
        _MemProfilerCard(state: memState),
        const SizedBox(height: ZapSpacing.lg),

        // Breakdown bars
        const _SectionLabel('MEMORY BREAKDOWN  ·  BY COMPONENT'),
        const SizedBox(height: ZapSpacing.md),
        _MemBreakdown(applied: applied),
        const SizedBox(height: ZapSpacing.lg),

        // Total gauge
        _TotalMemGauge(beforeMb: _beforeTotal, afterMb: after),
        const SizedBox(height: ZapSpacing.lg),

        // Fix cards
        const _SectionLabel('APPLY MEMORY FIXES'),
        const SizedBox(height: ZapSpacing.md),
        ..._kMemFixes.asMap().entries.map((e) {
          final i   = e.key;
          final fix = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _MemFixCard(
              fix: fix,
              done: applied[i],
              onApply: () async {
                await Future.delayed(const Duration(milliseconds: 500));
                if (!context.mounted) return;
                final updated = List<bool>.from(ref.read(_appliedProvider));
                updated[i] = true;
                ref.read(_appliedProvider.notifier).state = updated;
              },
            ),
          );
        }),
      ],
    );
  }
}

class _MemProfilerCard extends ConsumerWidget {
  final _MemState state;
  const _MemProfilerCard({required this.state});

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
        _codeNote('terminal',
            'flutter run --profile\n'
            '# DevTools → Memory → Heap snapshot'),
        const SizedBox(height: ZapSpacing.md),
        if (state == _MemState.idle)
          _actionButton(
            label: 'Take heap snapshot',
            icon: Icons.camera_alt_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () async {
              ref.read(_memProfileProvider.notifier).state = _MemState.profiling;
              await Future.delayed(const Duration(milliseconds: 1400));
              if (!context.mounted) return;
              ref.read(_memProfileProvider.notifier).state = _MemState.done;
            },
          )
        else if (state == _MemState.profiling)
          _statusChip(Icons.hourglass_top_rounded,
              const Color(0xFF8B5CF6), 'Collecting heap snapshot…', loading: true)
        else ...[
          _statusChip(Icons.check_circle_rounded,
              const Color(0xFFEF4444), 'Peak heap: 195 MB — action required'),
          const SizedBox(height: ZapSpacing.md),
          Row(children: [
            _statBox('195 MB', 'Peak heap',      const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _statBox('68 MB',  'Image cache',    const Color(0xFFF97316)),
            const SizedBox(width: ZapSpacing.sm),
            _statBox('44 MB',  'GPS buffer',     const Color(0xFFF59E0B)),
          ]),
        ],
      ]),
    );
  }
}

class _MemBreakdown extends StatelessWidget {
  final List<bool> applied;
  const _MemBreakdown({required this.applied});

  @override
  Widget build(BuildContext context) {
    const maxMb = 70.0;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _kMemComponents.asMap().entries.map((e) {
          final i   = e.key;
          final c   = e.value;
          // Check if the corresponding fix (if any) is applied
          final fixIdx = i < _kMemFixes.length ? i : -1;
          final fixDone = fixIdx >= 0 && fixIdx < applied.length && applied[fixIdx];
          final currentMb = fixDone ? c.afterMb : c.beforeMb;
          final isLast = i == _kMemComponents.length - 1;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(c.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        '$currentMb MB',
                        key: ValueKey(currentMb),
                        style: TextStyle(
                          color: fixDone
                              ? const Color(0xFF10B981)
                              : currentMb > 20
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (fixDone)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.arrow_downward_rounded,
                            color: Color(0xFF10B981), size: 12),
                      ),
                  ]),
                  const SizedBox(height: ZapSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      child: LinearProgressIndicator(
                        value: currentMb / maxMb,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(
                          fixDone ? const Color(0xFF10B981) : c.color,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  if (!fixDone)
                    Text(c.cause,
                        style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                            height: 1.3)),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
}

class _TotalMemGauge extends StatelessWidget {
  final int beforeMb, afterMb;
  const _TotalMemGauge({required this.beforeMb, required this.afterMb});

  @override
  Widget build(BuildContext context) {
    final pct = afterMb / beforeMb;
    final achieved = afterMb < 120;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: achieved
            ? const Color(0xFF10B981).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: achieved
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Peak RAM',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 11)),
              Row(children: [
                Text('$afterMb MB',
                    style: TextStyle(
                      color: achieved
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    )),
                const Text(' / 195 MB before',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ]),
              Text(
                achieved
                    ? '✅ Target < 120 MB achieved'
                    : 'Apply fixes above to reach target',
                style: TextStyle(
                    color: achieved
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                    fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        SizedBox(
          width: 60,
          child: Column(children: [
            CircularProgressIndicator(
              value: 1 - pct,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(
                achieved
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
              strokeWidth: 6,
            ),
            const SizedBox(height: 6),
            Text('${((1 - pct) * 100).round()}%\nsaved',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

class _MemFixCard extends StatefulWidget {
  final _MemFix fix;
  final bool done;
  final VoidCallback onApply;
  const _MemFixCard(
      {required this.fix, required this.done, required this.onApply});

  @override
  State<_MemFixCard> createState() => _MemFixCardState();
}

class _MemFixCardState extends State<_MemFixCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fix = widget.fix;
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.done
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : fix.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.done ? Icons.check_rounded : Icons.memory_rounded,
                  color: widget.done ? const Color(0xFF10B981) : fix.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fix.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('−${fix.savedMb} MB  ·  ${fix.area}',
                        style: TextStyle(
                            color: fix.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
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
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Column(children: [
                    const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                    Text(fix.desc,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            height: 1.5)),
                    const SizedBox(height: ZapSpacing.md),
                    _diffBlock(fix.codeFile, fix.codeBefore, fix.codeAfter),
                    const SizedBox(height: ZapSpacing.md),
                    widget.done
                        ? _statusChip(Icons.check_circle_rounded,
                            const Color(0xFF10B981), 'Applied ✅')
                        : _actionButton(
                            label: 'Apply fix  (−${fix.savedMb} MB)',
                            icon: Icons.memory_rounded,
                            color: fix.color,
                            onTap: widget.onApply),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ── Lazy Load Tab ──────────────────────────────────────────────────────────────
class _LazyLoadTab extends ConsumerWidget {
  final List<bool> lazyApplied;
  const _LazyLoadTab({required this.lazyApplied});

  int get _eagerKb =>
      _kLazyScreens.fold(0, (s, sc) => s + sc.estimatedKb);

  int get _criticalKb => _kLazyScreens
      .where((s) => s.critical)
      .fold(0, (s, sc) => s + sc.estimatedKb);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied     = lazyApplied;
    final lazyCount   = _kLazyScreens.where((s) => !s.critical).length;
    final doneCount   = applied.where((a) => a).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.layers_rounded,
          color: const Color(0xFF3B82F6),
          text: 'All 130+ screens are imported and compiled into the '
              'initial route tree. The non-critical 7 (Analytics, Vault, '
              'Map, etc.) consume ~524 KB of Dart code that is '
              'loaded even if the user never visits.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Stats
        Row(children: [
          _statBox('$_eagerKb KB', 'Eager total', const Color(0xFFEF4444)),
          const SizedBox(width: ZapSpacing.sm),
          _statBox('$_criticalKb KB', 'Critical path', const Color(0xFF10B981)),
          const SizedBox(width: ZapSpacing.sm),
          _statBox('${_eagerKb - _criticalKb} KB', 'Deferrable',
              const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Screen list
        const _SectionLabel('SCREENS  ·  TAP NON-CRITICAL TO LAZY-LOAD'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kLazyScreens.asMap().entries.map((e) {
              final i      = e.key;
              final screen = e.value;
              final isDone = applied[i];
              final isLast = i == _kLazyScreens.length - 1;

              return GestureDetector(
                onTap: !screen.critical && !isDone
                    ? () {
                        final updated = List<bool>.from(
                            ref.read(_lazyAppliedProvider));
                        updated[i] = true;
                        ref.read(_lazyAppliedProvider.notifier)
                            .state = updated;
                      }
                    : null,
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    color: isDone && !screen.critical
                        ? const Color(0xFF10B981).withOpacity(0.05)
                        : Colors.transparent,
                    child: Row(children: [
                      Icon(
                        screen.critical
                            ? Icons.lock_rounded
                            : isDone
                                ? Icons.schedule_rounded
                                : Icons.download_rounded,
                        color: screen.critical
                            ? const Color(0xFF6B7280)
                            : isDone
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6),
                        size: 16,
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(screen.name,
                                style: TextStyle(
                                  color: isDone && !screen.critical
                                      ? const Color(0xFF9CA3AF)
                                      : Colors.white,
                                  fontSize: 13,
                                )),
                            Text(screen.route,
                                style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 10,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: screen.critical
                              ? const Color(0xFF2A2A2A)
                              : isDone
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          screen.critical
                              ? 'Critical'
                              : isDone
                                  ? 'Lazy ✅'
                                  : '${screen.estimatedKb} KB',
                          style: TextStyle(
                            color: screen.critical
                                ? const Color(0xFF6B7280)
                                : isDone
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF3B82F6),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Text(
            '$doneCount / $lazyCount non-critical screens lazy-loaded '
            '· startup saves ${_kLazyScreens.where((s) => !s.critical).fold(0, (sum, s) => sum + s.estimatedKb)} KB',
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('app_router.dart',
            '// Before — eager import\n'
            'import \'../screens/analytics_screen.dart\';\n'
            '// ... 130 more imports\n'
            '\n'
            '// After — lazy builder\n'
            'GoRoute(\n'
            '  path: AppRoutes.analytics,\n'
            '  builder: (context, state) {\n'
            '    return const AnalyticsDashboardScreen();\n'
            '    // GoRouter only builds when navigated to\n'
            '  },\n'
            ')'),
      ],
    );
  }
}

// ── Low RAM Tab ────────────────────────────────────────────────────────────────
class _LowRamTab extends StatelessWidget {
  const _LowRamTab();

  static const _mitigations = [
    (Icons.phone_android_rounded,   Color(0xFFEF4444),
        'LITE tier auto-detection',
        'Detect < 2 GB RAM at startup via device_info_plus. '
        'Set DeviceTier.lite — disables TFLite models, '
        'reduces GPS accuracy, skips image caching.'),
    (Icons.compress_rounded,        Color(0xFFF97316),
        'Image quality scaling',
        'On LITE tier, load network images at 0.5× scale '
        'using ResizeImage wrapper. Halves memory per image.'),
    (Icons.timer_rounded,           Color(0xFFF59E0B),
        'Background service throttle',
        'On LITE tier, reduce audio sampling to 4 kHz (from 16 kHz) '
        'and poll GPS every 60s (from 30s). 40% less CPU.'),
    (Icons.warning_rounded,         Color(0xFF3B82F6),
        'OOM callback handler',
        'Register ComponentCallbacks2.onTrimMemory(). '
        'When TRIM_MEMORY_RUNNING_CRITICAL fires, '
        'flush image cache and clear GPS trace buffer immediately.'),
    (Icons.check_circle_rounded,    Color(0xFF10B981),
        'LITE tier test checklist',
        'Test on Xiaomi Redmi 9 (2 GB): 30 min session, '
        'trigger SOS, check Sentry — zero OOM events expected.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.phone_android_rounded,
          color: const Color(0xFFEF4444),
          text: '19 users (1.9%) reported crashes on phones with < 2 GB RAM '
              '(Xiaomi Redmi 9, Samsung A12). Root cause: OOM after TFLite '
              'model allocation on top of GPS + image cache.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionLabel('LOW-RAM MITIGATIONS'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _mitigations.asMap().entries.map((e) {
              final i = e.key;
              final (icon, color, title, desc) = e.value;
              final isLast = i == _mitigations.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _codeNote('background_engine.dart',
            '// OOM safety net\n'
            '@override\n'
            'void onTrimMemory(int level) {\n'
            '  if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) {\n'
            '    PaintingBinding.instance.imageCache.clear();\n'
            '    GpsService.instance.flushBuffer();\n'
            '    debugPrint(\'[Memory] Emergency flush — level: \$level\');\n'
            '  }\n'
            '}'),
      ],
    );
  }
}

// ── Verify checklist ───────────────────────────────────────────────────────────
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
                allDone ? '✅ Ready to ship v0.5.4' : 'Tap to verify',
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
                      : const Color(0xFF8B5CF6),
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

// ── Ship panel ─────────────────────────────────────────────────────────────────
class _ShipPanel extends ConsumerWidget {
  final bool allVerified;
  final _ShipState state;
  const _ShipPanel({required this.allVerified, required this.state});

  static const _kStates = [
    _ShipState.idle, _ShipState.building,
    _ShipState.uploading, _ShipState.done,
  ];
  static const _kLabels = [
    '', 'Building v0.5.4 release…',
    'Uploading to TestFlight + Play…', 'v0.5.4 live!',
  ];
  static const _kColors = [
    Color(0xFF8B5CF6), Color(0xFF8B5CF6),
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
        // Changelog
        _codeNote('changelog',
            'v0.5.4 — Performance Bundle (Days 129-130)\n'
            '⚡ Cold start: 5.2s → 1.8s (DB/TFLite/GPS deferred)\n'
            '⚡ Battery: 20%/hr → 6%/hr (adaptive GPS + batched audio)\n'
            '⚡ RAM: 195 MB → 58 MB (image cache + GPS buffer + Sentry)\n'
            '⚡ Lazy-loaded 7 non-critical screens\n'
            '⚡ Low-RAM < 2 GB: OOM handler + LITE tier throttle'),
        const SizedBox(height: ZapSpacing.md),

        if (state == _ShipState.done) ...[
          const Icon(Icons.rocket_launch_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.4 shipped!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Performance bundle complete.\n'
            'Days 129-130 done.',
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
                    ? const LinearGradient(colors: [
                        Color(0xFF059669), Color(0xFF10B981)])
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
                        ? 'Ship v0.5.4 — Performance bundle'
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
        _row(const Color(0xFF3B82F6), 'Days 131-132',
            'Fix memory leaks — dispose location listeners, '
            'cap DB connections, clear GPS trace buffers on screen pop'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF10B981), 'Days 133-134',
            'Simplify onboarding — 7 steps → 4, '
            'add permission context, target < 2 min total'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF8B5CF6), 'Day 135',
            'Bundle & release v0.5.5 with all fixes from '
            'Days 121-134 — complete beta iteration cycle'),
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
Widget _statBox(String value, String label, Color color) => Expanded(
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
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
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
