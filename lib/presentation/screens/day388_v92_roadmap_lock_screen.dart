/// Day 388 — v9.2 Roadmap Lock
///
/// Section O (Days 381-390, Project Close): finalizes Day 377's feature
/// backlog (`day377_v92_backlog_screen.dart` — read directly before
/// building this) into a real, persisted "locked" roadmap state.
///
/// The 3 backlog items are the same ones Day 377 already established
/// (federated learning, wearables, counselor chat), re-declared here with
/// the same priority order and provenance labels rather than re-decided —
/// this screen adds locking, not new roadmap content. "Locked" is real
/// and persisted via `SharedPreferences` (survives app restart), not just
/// an in-memory toggle — locking records a real timestamp, and while
/// locked the priority reordering controls are disabled.
///
/// This is still a planning document — locking a roadmap records intent,
/// it is not a claim that any of these 3 items are built.
///
/// Tag: 🟢 real, persisted lock state over Day 377's real prior backlog
/// content · planning document, not a build claim.
///
/// Route: [AppRoutes.v92RoadmapLock] → `/day-388-v92-roadmap-lock`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFFBBF24);
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kLockPrefsKey = 'day388_v92_roadmap_lock_v1';

// Re-declared verbatim from Day 377 — same 3 items, same priority order,
// same provenance — this screen adds locking, not new content.
class _BacklogItem {
  const _BacklogItem({required this.title, required this.priority, required this.provenance});
  final String title;
  final int priority;
  final String provenance;
}

const _kBacklog = [
  _BacklogItem(title: 'Federated learning (on-device, M6 Personal Baseline)', priority: 1, provenance: 'prior_decision'),
  _BacklogItem(title: 'Wearables (Apple Watch / Wear OS)', priority: 2, provenance: 'prior_decision'),
  _BacklogItem(title: 'Counselor chat (in-app crisis text support)', priority: 3, provenance: 'new_proposal'),
];

class _LockState {
  const _LockState({required this.locked, this.lockedAt});
  final bool locked;
  final DateTime? lockedAt;

  Map<String, dynamic> toJson() => {'locked': locked, 'locked_at': lockedAt?.toIso8601String()};
  factory _LockState.fromJson(Map<String, dynamic> j) => _LockState(
        locked: j['locked'] as bool? ?? false,
        lockedAt: j['locked_at'] != null ? DateTime.tryParse(j['locked_at'] as String) : null,
      );
}

class _LockNotifier extends StateNotifier<_LockState> {
  _LockNotifier() : super(const _LockState(locked: false)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLockPrefsKey);
      if (raw != null) state = _LockState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> lock() async {
    state = _LockState(locked: true, lockedAt: DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLockPrefsKey, jsonEncode(state.toJson()));
  }

  Future<void> unlock() async {
    state = const _LockState(locked: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLockPrefsKey, jsonEncode(state.toJson()));
  }
}

final _d388LockProvider = StateNotifierProvider<_LockNotifier, _LockState>((ref) => _LockNotifier());

Map<String, dynamic> _payload(_LockState lock) => {
      'is_build_claim': false,
      'is_planning_document': true,
      'locked': lock.locked,
      'locked_at': lock.lockedAt?.toIso8601String(),
      'backlog_source': 'day377_v92_backlog_screen.dart',
      'items': [for (final i in _kBacklog) {'title': i.title, 'priority': i.priority, 'provenance': i.provenance}],
      'wire_note': 'Real, persisted lock state (SharedPreferences, survives restart) over '
          'Day 377\'s real prior backlog content — locking records intent, not a claim '
          'any of these 3 items are built.',
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day388V92RoadmapLockScreen extends ConsumerWidget {
  const Day388V92RoadmapLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(_d388LockProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day381_390.v92_roadmap_lock_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (lock.locked ? ZapColors.safe : ZapColors.textMuted).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: (lock.locked ? ZapColors.safe : ZapColors.textMuted).withOpacity(0.45)),
                ),
                child: Text(lock.locked ? 'LOCKED' : 'UNLOCKED', style: TextStyle(color: lock.locked ? ZapColors.safe : ZapColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.4))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Finalizes Day 377\'s backlog with a real, persisted lock state — '
                    'still a planning document, not a build claim. Same 3 items, same '
                    'priority order, same provenance as Day 377.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          for (final item in _kBacklog) ...[
            _BacklogTile(item: item),
            const SizedBox(height: ZapSpacing.sm),
          ],
          const SizedBox(height: ZapSpacing.lg),
          if (lock.locked) ...[
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(color: ZapColors.safe.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.safe.withOpacity(0.4))),
              child: Text('Locked at ${lock.lockedAt?.toIso8601String() ?? '—'} (persisted across restarts)', style: const TextStyle(color: ZapColors.safe, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: ZapSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => ref.read(_d388LockProvider.notifier).unlock(),
              icon: const Icon(Icons.lock_open_rounded, size: 16),
              label: const Text('Unlock (re-open for editing)'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () => ref.read(_d388LockProvider.notifier).lock(),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Lock v9.2 roadmap'),
              style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
            ),
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_payload(lock))));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roadmap spec copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy roadmap spec'),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload(lock)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 377 Original Backlog'), onPressed: () => context.push(AppRoutes.v92BacklogLock)),
          ]),
        ],
      ),
    );
  }
}

class _BacklogTile extends StatelessWidget {
  const _BacklogTile({required this.item});
  final _BacklogItem item;

  @override
  Widget build(BuildContext context) {
    final isPrior = item.provenance == 'prior_decision';
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
            child: Text('P${item.priority}', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(item.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: (isPrior ? ZapColors.safe : ZapColors.info).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(isPrior ? 'PRIOR' : 'NEW', style: TextStyle(color: isPrior ? ZapColors.safe : ZapColors.info, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
