/// Day 122-123 — Fix Top 3 Crashes
///
/// Working through the three most-impactful crashes identified in Day 121:
///   1. Android 11 SMS crash (P0 · 51 users · 5.1%)
///   2. iPhone 7 out-of-memory / location leak (P0 · 32 users · 3.2%)
///   3. TFLite scream model OOM on LITE-tier devices (P1 · 19 users · 1.9%)
///
/// For each crash: stack trace → root cause → code diff → test checklist.
/// Simulated fix flow: fix code → build → test → upload hotfix v0.5.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeCrashProvider  = StateProvider<int>((ref) => 0);
final _fixStatesProvider    = StateProvider<List<_FixState>>(
  (ref) => List.filled(3, _FixState.pending),
);
final _buildStateProvider   = StateProvider<_BuildState>((ref) => _BuildState.idle);
final _testChecklistProvider = StateProvider<List<List<bool>>>(
  (ref) => [
    List.filled(_kTestChecks[0].length, false),
    List.filled(_kTestChecks[1].length, false),
    List.filled(_kTestChecks[2].length, false),
  ],
);

enum _FixState  { pending, inProgress, done }
enum _BuildState { idle, building, testing, uploading, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Crash {
  final String id;
  final String priority;
  final Color  priorityColor;
  final String title;
  final int    affectedUsers;
  final double affectedPct;
  final String os;
  final List<String> stackTrace;
  final String rootCause;
  final String fix;
  final List<_DiffLine> diff;
  const _Crash({
    required this.id,
    required this.priority,
    required this.priorityColor,
    required this.title,
    required this.affectedUsers,
    required this.affectedPct,
    required this.os,
    required this.stackTrace,
    required this.rootCause,
    required this.fix,
    required this.diff,
  });
}

class _DiffLine {
  final String text;
  final _DiffType type;
  const _DiffLine(this.text, this.type);
}

enum _DiffType { context, removed, added }

const _kCrashes = [
  _Crash(
    id: 'android_11_sms',
    priority: 'P0', priorityColor: Color(0xFFEF4444),
    title: 'Android 11 SMS crash on SOS send',
    affectedUsers: 51, affectedPct: 5.1,
    os: 'Android 11 · Samsung One UI 3',
    stackTrace: [
      '#0  SecurityException: Permission denied (missing SEND_SMS)',
      '#1  SosService.sendSms (sos_service.dart:142)',
      '#2  SosBloc._onTrigger (sos_bloc.dart:88)',
      '#3  _SosActiveScreenState.build (sos_active_screen.dart:34)',
    ],
    rootCause:
        'Android 11 (API 30) tightened SMS permission handling. '
        'The old requestPermissions() call throws SecurityException when '
        'SEND_SMS is not granted at runtime — no try-catch existed.',
    fix:
        'Wrap SMS send in try-catch, migrate to '
        'ActivityResultContracts.RequestPermission, '
        'show graceful fallback (push-only) when SMS denied.',
    diff: [
      _DiffLine('  Future<void> sendSms(String phone, String msg) async {', _DiffType.context),
      _DiffLine('-   SmsManager.getDefault().sendTextMessage(phone, null, msg, null, null);', _DiffType.removed),
      _DiffLine('+   try {', _DiffType.added),
      _DiffLine('+     if (!await _hasSmsPermission()) {', _DiffType.added),
      _DiffLine('+       await _requestSmsPermission();', _DiffType.added),
      _DiffLine('+     }', _DiffType.added),
      _DiffLine('+     SmsManager.getDefault().sendTextMessage(phone, null, msg, null, null);', _DiffType.added),
      _DiffLine('+   } on SecurityException catch (e) {', _DiffType.added),
      _DiffLine('+     _log.warning("SMS denied, falling back to push: \$e");', _DiffType.added),
      _DiffLine('+     await _sendPushFallback(phone, msg);', _DiffType.added),
      _DiffLine('+   }', _DiffType.added),
      _DiffLine('  }', _DiffType.context),
    ],
  ),
  _Crash(
    id: 'ios_oom_location',
    priority: 'P0', priorityColor: Color(0xFFEF4444),
    title: 'iPhone 7 OOM after 20 min — location memory leak',
    affectedUsers: 32, affectedPct: 3.2,
    os: 'iOS 15 · iPhone 7 (2 GB RAM)',
    stackTrace: [
      '#0  EXC_RESOURCE EXCEPTION — Memory limit exceeded (180 MB)',
      '#1  CLLocationManager._updateBuffer (CLLocationManager.m:—)',
      '#2  GpsService._startTracking (gps_service.dart:78)',
      '#3  BackgroundEngine.init (background_engine.dart:55)',
    ],
    rootCause:
        'CLLocationManager.stopUpdatingLocation() was never called on '
        'screen dismiss. Each navigation pushed a new GpsService instance '
        'without disposing the previous one — GPS buffers accumulated.',
    fix:
        'Call stopUpdatingLocation() in dispose(), '
        'set desiredAccuracy to kCLLocationAccuracyHundredMeters on LITE tier, '
        'cap GPS trace buffer to 500 entries.',
    diff: [
      _DiffLine('  class GpsService {', _DiffType.context),
      _DiffLine('    late CLLocationManager _manager;', _DiffType.context),
      _DiffLine('+   static const _kMaxBuffer = 500;', _DiffType.added),
      _DiffLine('', _DiffType.context),
      _DiffLine('    void start() {', _DiffType.context),
      _DiffLine('      _manager = CLLocationManager();', _DiffType.context),
      _DiffLine('-     _manager.desiredAccuracy = kCLLocationAccuracyBest;', _DiffType.removed),
      _DiffLine('+     _manager.desiredAccuracy = _isLiteTier', _DiffType.added),
      _DiffLine('+         ? kCLLocationAccuracyHundredMeters', _DiffType.added),
      _DiffLine('+         : kCLLocationAccuracyBest;', _DiffType.added),
      _DiffLine('      _manager.startUpdatingLocation();', _DiffType.context),
      _DiffLine('    }', _DiffType.context),
      _DiffLine('', _DiffType.context),
      _DiffLine('+   @override', _DiffType.added),
      _DiffLine('+   void dispose() {', _DiffType.added),
      _DiffLine('+     _manager.stopUpdatingLocation();', _DiffType.added),
      _DiffLine('+     _buffer.clear();', _DiffType.added),
      _DiffLine('+     super.dispose();', _DiffType.added),
      _DiffLine('+   }', _DiffType.added),
      _DiffLine('  }', _DiffType.context),
    ],
  ),
  _Crash(
    id: 'tflite_oom_lite',
    priority: 'P1', priorityColor: Color(0xFFF97316),
    title: 'TFLite scream model OOM on < 2 GB RAM devices',
    affectedUsers: 19, affectedPct: 1.9,
    os: 'Android 12 · Xiaomi Redmi 9 (2 GB RAM)',
    stackTrace: [
      '#0  OutOfMemoryError: Failed to allocate tensor arena (180 MB)',
      '#1  ScreamClassifier._loadModel (scream_classifier.dart:201)',
      '#2  DcsEngine.init (dcs_engine.dart:44)',
      '#3  BackgroundEngine.init (background_engine.dart:55)',
    ],
    rootCause:
        'INT8 scream model requires 180 MB tensor arena — exceeds available '
        'memory on LITE-tier devices (< 2 GB RAM). No tier-check before '
        'model load attempted full allocation on low-RAM devices.',
    fix:
        'Check DeviceTier before loading model. '
        'LITE tier → load StubScreamClassifier (returns 0.0 score). '
        'Show "AI detection unavailable on this device" notice in settings.',
    diff: [
      _DiffLine('  Future<void> init() async {', _DiffType.context),
      _DiffLine('    final tier = await DeviceTierService.detect();', _DiffType.context),
      _DiffLine('-   _scream = await ScreamClassifier.load();', _DiffType.removed),
      _DiffLine('+   _scream = tier == DeviceTier.lite', _DiffType.added),
      _DiffLine('+       ? StubScreamClassifier()', _DiffType.added),
      _DiffLine('+       : await ScreamClassifier.load();', _DiffType.added),
      _DiffLine('+   if (tier == DeviceTier.lite) {', _DiffType.added),
      _DiffLine('+     _notifyLiteLimit("Scream detection unavailable on this device");', _DiffType.added),
      _DiffLine('+   }', _DiffType.added),
      _DiffLine('  }', _DiffType.context),
    ],
  ),
];

const _kTestChecks = [
  [ // Crash 1
    'Reproduce on Android 11 emulator — confirm crash gone',
    'Test on Samsung Android 11 physical device',
    'Verify SMS still sends when permission granted',
    'Verify graceful fallback when SMS permission denied',
    'Test on Android 12 & 13 — no regression',
  ],
  [ // Crash 2
    'Run app on iPhone 7 for 30 min — no OOM',
    'Profile memory in Xcode Instruments (confirm < 120 MB)',
    'Verify GPS accuracy reduced on LITE tier',
    'Test location sharing still works after fix',
    'Test on iPhone SE 2020 — no regression',
  ],
  [ // Crash 3
    'Install on Xiaomi Redmi 9 (< 2 GB RAM) — confirm no crash',
    'Verify "AI detection unavailable" notice shown on LITE tier',
    'Confirm normal tier devices still load full model',
    'Test DCS engine still functions on STANDARD tier',
    'Memory profile — LITE tier heap stays under 80 MB',
  ],
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day122CrashFixesScreen extends ConsumerWidget {
  const Day122CrashFixesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active     = ref.watch(_activeCrashProvider);
    final fixStates  = ref.watch(_fixStatesProvider);
    final buildState = ref.watch(_buildStateProvider);
    final allFixed   = fixStates.every((s) => s == _FixState.done);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 122-123 · Fix Top 3 Crashes'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Crash selector
            const _SectionLabel('SELECT CRASH TO FIX'),
            const SizedBox(height: ZapSpacing.md),
            _CrashSelector(active: active, fixStates: fixStates),
            const SizedBox(height: ZapSpacing.xl),

            // Active crash detail
            _CrashDetail(crash: _kCrashes[active], crashIndex: active),
            const SizedBox(height: ZapSpacing.xl),

            // Before/after metrics
            const _SectionLabel('CRASH RATE  ·  BEFORE VS AFTER'),
            const SizedBox(height: ZapSpacing.md),
            const _CrashRateCard(),
            const SizedBox(height: ZapSpacing.xl),

            // Hotfix build
            const _SectionLabel('HOTFIX BUILD  ·  v0.5.1'),
            const SizedBox(height: ZapSpacing.md),
            _HotfixBuilder(allFixed: allFixed, buildState: buildState),
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
          colors: [Color(0xFF1A0505), Color(0xFF0D0202), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 122-123', const Color(0xFFEF4444)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Hotfix v0.5.1', const Color(0xFFF97316)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Fix Top 3 Crashes',
            style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Two days to fix the 3 most-impactful crashes from Day 121 analysis. '
            '102 users affected · 2 P0s + 1 P1 · '
            'Target: crash rate 0.31% → < 0.10%.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('102',    'Users affected', Color(0xFFEF4444)),
            _HStat('2',      'P0 crashes',     Color(0xFFEF4444)),
            _HStat('1',      'P1 crash',       Color(0xFFF97316)),
            _HStat('v0.5.1', 'Hotfix build',   Color(0xFF10B981)),
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
                  color: color, fontSize: 15, fontWeight: FontWeight.w800),
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

// ── Crash selector ─────────────────────────────────────────────────────────────
class _CrashSelector extends ConsumerWidget {
  final int active;
  final List<_FixState> fixStates;
  const _CrashSelector({required this.active, required this.fixStates});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: List.generate(_kCrashes.length, (i) {
        final crash    = _kCrashes[i];
        final isActive = i == active;
        final state    = fixStates[i];
        final color    = crash.priorityColor;

        return Expanded(
          child: GestureDetector(
            onTap: () =>
                ref.read(_activeCrashProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                // Status icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: state == _FixState.done
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state == _FixState.done
                        ? Icons.check_rounded
                        : state == _FixState.inProgress
                            ? Icons.build_rounded
                            : Icons.bug_report_rounded,
                    color: state == _FixState.done
                        ? const Color(0xFF10B981)
                        : color,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(crash.priority,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                Text('Crash ${i + 1}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 9)),
                const SizedBox(height: ZapSpacing.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: state == _FixState.done
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : state == _FixState.inProgress
                            ? color.withOpacity(0.12)
                            : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    state == _FixState.done
                        ? 'Fixed'
                        : state == _FixState.inProgress
                            ? 'In progress'
                            : 'Pending',
                    style: TextStyle(
                      color: state == _FixState.done
                          ? const Color(0xFF10B981)
                          : state == _FixState.inProgress
                              ? color
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

// ── Crash detail ───────────────────────────────────────────────────────────────
class _CrashDetail extends ConsumerWidget {
  final _Crash crash;
  final int crashIndex;
  const _CrashDetail({required this.crash, required this.crashIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixStates   = ref.watch(_fixStatesProvider);
    final fixState    = fixStates[crashIndex];
    final testChecks  = ref.watch(_testChecklistProvider);
    final myChecks    = testChecks[crashIndex];
    final checksDone  = myChecks.where((c) => c).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + meta
        _SectionLabel('CRASH ${crashIndex + 1}  ·  ${crash.priority}'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: crash.priorityColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: crash.priorityColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: crash.priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(crash.priority,
                      style: TextStyle(
                          color: crash.priorityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(crash.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: ZapSpacing.sm),
              Row(children: [
                Icon(Icons.smartphone_rounded,
                    color: crash.priorityColor, size: 14),
                const SizedBox(width: ZapSpacing.xs),
                Text(crash.os,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
                const Spacer(),
                Text(
                  '${crash.affectedUsers} users (${crash.affectedPct}%)',
                  style: TextStyle(
                      color: crash.priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Stack trace
        const _SectionLabel('STACK TRACE'),
        const SizedBox(height: ZapSpacing.md),
        _codeBlock(crash.stackTrace.map((l) => (l, _DiffType.context)).toList(),
            showLineNumbers: false),
        const SizedBox(height: ZapSpacing.lg),

        // Root cause
        const _SectionLabel('ROOT CAUSE'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.06),
            borderRadius:
                BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.search_rounded,
                color: Color(0xFFEF4444), size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(crash.rootCause,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12,
                      height: 1.6)),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Fix
        const _SectionLabel('FIX'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.06),
            borderRadius:
                BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.build_rounded,
                color: Color(0xFF10B981), size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(crash.fix,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12,
                      height: 1.6)),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Code diff
        const _SectionLabel('CODE DIFF'),
        const SizedBox(height: ZapSpacing.md),
        _codeBlock(crash.diff.map((d) => (d.text, d.type)).toList(),
            showLineNumbers: true),
        const SizedBox(height: ZapSpacing.lg),

        // Apply fix button
        _ApplyFixButton(crashIndex: crashIndex, fixState: fixState),
        const SizedBox(height: ZapSpacing.lg),

        // Test checklist (shows when fix applied)
        if (fixState == _FixState.done || fixState == _FixState.inProgress) ...[
          _SectionLabel('TEST CHECKLIST  ·  $checksDone / ${myChecks.length} passed'),
          const SizedBox(height: ZapSpacing.md),
          _TestChecklist(crashIndex: crashIndex),
        ],
      ],
    );
  }
}

// ── Code block renderer ────────────────────────────────────────────────────────
Widget _codeBlock(List<(String, _DiffType)> lines, {bool showLineNumbers = false}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ZapSpacing.md),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1117),
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      border: Border.all(color: const Color(0xFF30363D)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((e) {
        final i = e.key;
        final (text, type) = e.value;
        if (text.isEmpty) return const SizedBox(height: 6);

        Color bg = Colors.transparent;
        Color fg = const Color(0xFFE6EDF3);
        String prefix = '  ';

        if (type == _DiffType.removed) {
          bg = const Color(0xFFEF4444).withOpacity(0.12);
          fg = const Color(0xFFFF7B72);
          prefix = '- ';
        } else if (type == _DiffType.added) {
          bg = const Color(0xFF10B981).withOpacity(0.12);
          fg = const Color(0xFF7EE787);
          prefix = '+ ';
        }

        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showLineNumbers)
                SizedBox(
                  width: 24,
                  child: Text(
                    type == _DiffType.context ? '${i + 1}' : '',
                    style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.right,
                  ),
                ),
              if (showLineNumbers) const SizedBox(width: ZapSpacing.sm),
              Text(prefix,
                  style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700)),
              Expanded(
                child: Text(text.trim(),
                    style: TextStyle(
                        color: fg, fontSize: 11, fontFamily: 'monospace', height: 1.5)),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

// ── Apply fix button ───────────────────────────────────────────────────────────
class _ApplyFixButton extends ConsumerWidget {
  final int crashIndex;
  final _FixState fixState;
  const _ApplyFixButton({required this.crashIndex, required this.fixState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fixState == _FixState.done) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Fix applied & committed',
                style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (fixState == _FixState.inProgress) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Color(0xFF3B82F6), strokeWidth: 2),
            ),
            SizedBox(width: ZapSpacing.sm),
            Text('Applying fix…',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 14)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        final states = List<_FixState>.from(
            ref.read(_fixStatesProvider));
        states[crashIndex] = _FixState.inProgress;
        ref.read(_fixStatesProvider.notifier).state = states;

        await Future.delayed(const Duration(milliseconds: 1200));
        if (!context.mounted) return;

        final updated = List<_FixState>.from(
            ref.read(_fixStatesProvider));
        updated[crashIndex] = _FixState.done;
        ref.read(_fixStatesProvider.notifier).state = updated;
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_rounded, color: Colors.white, size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Apply fix & commit',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Test checklist ─────────────────────────────────────────────────────────────
class _TestChecklist extends ConsumerWidget {
  final int crashIndex;
  const _TestChecklist({required this.crashIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all    = ref.watch(_testChecklistProvider);
    final checks = all[crashIndex];
    final items  = _kTestChecks[crashIndex];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final done   = checks[i];
          final isLast = i == items.length - 1;
          return GestureDetector(
            onTap: () {
              final updated = all.map((list) => List<bool>.from(list)).toList();
              updated[crashIndex][i] = !updated[crashIndex][i];
              ref.read(_testChecklistProvider.notifier).state = updated;
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 12),
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
                    child: Text(items[i],
                        style: TextStyle(
                          color: done
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                          fontSize: 13,
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
      ),
    );
  }
}

// ── Crash rate card ────────────────────────────────────────────────────────────
class _CrashRateCard extends ConsumerWidget {
  const _CrashRateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixStates = ref.watch(_fixStatesProvider);
    final fixedCount = fixStates.where((s) => s == _FixState.done).length;
    final newRate = 0.31 - (fixedCount * 0.07);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(children: [
          const Expanded(child: _RateBox('Before', '0.31%', Color(0xFFEF4444))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF4B5563), size: 20),
          ),
          Expanded(
            child: _RateBox(
              'After',
              '${newRate.toStringAsFixed(2)}%',
              fixedCount > 0 ? const Color(0xFF10B981) : const Color(0xFF6B7280),
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fixedCount / 3,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          fixedCount == 0
              ? 'Fix crashes above to see rate drop'
              : fixedCount == 3
                  ? '✅ All 3 crashes fixed — target < 0.10% achieved'
                  : '$fixedCount / 3 crashes fixed',
          style: TextStyle(
            color: fixedCount == 3
                ? const Color(0xFF10B981)
                : const Color(0xFF9CA3AF),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _RateBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RateBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const Text('crash rate',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
      ]),
    );
  }
}

// ── Hotfix builder ─────────────────────────────────────────────────────────────
class _HotfixBuilder extends ConsumerWidget {
  final bool allFixed;
  final _BuildState buildState;
  const _HotfixBuilder(
      {required this.allFixed, required this.buildState});

  static const _kBuildSteps = [
    (Icons.build_rounded,         Color(0xFF3B82F6), 'Building release AAB…'),
    (Icons.verified_rounded,      Color(0xFF8B5CF6), 'Running test suite…'),
    (Icons.cloud_upload_rounded,  Color(0xFFF59E0B), 'Uploading to TestFlight + Play…'),
    (Icons.check_circle_rounded,  Color(0xFF10B981), 'v0.5.1 live!'),
  ];

  static const _kStates = [
    _BuildState.idle,
    _BuildState.building,
    _BuildState.testing,
    _BuildState.uploading,
    _BuildState.done,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: buildState == _BuildState.done
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        if (!allFixed && buildState == _BuildState.idle)
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
                child: Text('Apply all 3 fixes before building hotfix',
                    style: TextStyle(
                        color: Color(0xFFF59E0B), fontSize: 11)),
              ),
            ]),
          ),

        if (buildState == _BuildState.done) ...[
          const Icon(Icons.rocket_launch_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.1 shipped!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '3 crashes fixed · crash rate 0.31% → 0.10% · '
            'release notes sent to 847 active testers.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () => ref
                .read(_buildStateProvider.notifier)
                .state = _BuildState.idle,
            child: const Text('Reset',
                style: TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12)),
          ),
        ] else if (buildState != _BuildState.idle) ...[
          ...List.generate(_kBuildSteps.length, (i) {
            final stateIdx = _kStates.indexOf(buildState);
            final isDone   = i < stateIdx - 1;
            final isActive = i == stateIdx - 1;
            final (_, color, label) = _kBuildSteps[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : isActive
                            ? color.withOpacity(0.15)
                            : const Color(0xFF111111),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : isActive
                              ? color.withOpacity(0.6)
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
                                  color: color, strokeWidth: 2),
                            )
                          : null,
                ),
                const SizedBox(width: ZapSpacing.md),
                Text(label,
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
          }),
        ] else ...[
          GestureDetector(
            onTap: allFixed
                ? () async {
                    for (final s in _kStates.skip(1)) {
                      if (!context.mounted) return;
                      ref.read(_buildStateProvider.notifier).state = s;
                      await Future.delayed(
                          const Duration(milliseconds: 900));
                    }
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: allFixed
                    ? const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)])
                    : null,
                color: allFixed ? null : const Color(0xFF111111),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: allFixed
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
                border: allFixed
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      color: allFixed
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 20),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    allFixed
                        ? 'Build & ship hotfix v0.5.1'
                        : 'Apply all fixes first',
                    style: TextStyle(
                      color: allFixed
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
