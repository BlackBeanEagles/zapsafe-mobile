/// Day 245 — Offline SOS UX (No Signal)
///
/// Section C (Days 241-260): educate + demo offline SOS — airplane mode
/// simulation, local evidence/GPS queue, flush when connectivity returns.
///
/// Tag: 🟢 FRONTEND-ONLY · SOS works offline · alerts send when signal returns.
///
/// Route: [AppRoutes.offlineSosUx] → `/offline-sos-ux`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF14B8A6);
const _kTabs = ['Simulate', 'Queue', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
final _kTimeFmt = DateFormat('HH:mm:ss');

// ── Models ────────────────────────────────────────────────────────────────────
enum _QueueStatus { pending, uploading, synced, failed }

enum _QueueType { gpsBatch, evidenceMeta, smsAlert, pushAlert }

class _QueueItem {
  const _QueueItem({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.sizeKb,
    required this.queuedAt,
    required this.status,
  });

  final String id;
  final _QueueType type;
  final String title;
  final String detail;
  final int sizeKb;
  final DateTime queuedAt;
  final _QueueStatus status;

  _QueueItem copyWith({_QueueStatus? status}) => _QueueItem(
        id: id,
        type: type,
        title: title,
        detail: detail,
        sizeKb: sizeKb,
        queuedAt: queuedAt,
        status: status ?? this.status,
      );

  IconData get icon => switch (type) {
        _QueueType.gpsBatch => Icons.my_location_rounded,
        _QueueType.evidenceMeta => Icons.mic_rounded,
        _QueueType.smsAlert => Icons.sms_rounded,
        _QueueType.pushAlert => Icons.notifications_active_rounded,
      };

  Color get typeColor => switch (type) {
        _QueueType.gpsBatch => ZapColors.info,
        _QueueType.evidenceMeta => ZapColors.warning,
        _QueueType.smsAlert => _kAccent,
        _QueueType.pushAlert => const Color(0xFF8B5CF6),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'detail': detail,
        'size_kb': sizeKb,
        'queued_at': queuedAt.toIso8601String(),
        'status': status.name,
      };
}

List<_QueueItem> _seedQueue() {
  final now = DateTime.now();
  return [
    _QueueItem(
      id: 'q_gps_01',
      type: _QueueType.gpsBatch,
      title: 'GPS batch · 12 points',
      detail: 'SOS stream · 10s interval · lat/lng + accuracy',
      sizeKb: 4,
      queuedAt: now.subtract(const Duration(minutes: 3)),
      status: _QueueStatus.pending,
    ),
    _QueueItem(
      id: 'q_ev_01',
      type: _QueueType.evidenceMeta,
      title: 'Evidence metadata',
      detail: 'Audio clip 0:45 · SHA-256 pending upload',
      sizeKb: 128,
      queuedAt: now.subtract(const Duration(minutes: 2, seconds: 40)),
      status: _QueueStatus.pending,
    ),
  ];
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d245TabProvider = StateProvider<int>((ref) => 0);
final _d245AirplaneModeProvider = StateProvider<bool>((ref) => false);
final _d245QueueProvider = StateProvider<List<_QueueItem>>((ref) => _seedQueue());
final _d245SosOfflineTriggeredProvider = StateProvider<bool>((ref) => false);
final _d245FlushingProvider = StateProvider<bool>((ref) => false);
final _d245LastFlushAtProvider = StateProvider<DateTime?>((ref) => null);
final _d245DispatchCountProvider = StateProvider<int>((ref) => 0);

// ── Helpers ───────────────────────────────────────────────────────────────────
int _pendingCount(List<_QueueItem> items) =>
    items.where((i) => i.status == _QueueStatus.pending).length;

int _syncedCount(List<_QueueItem> items) =>
    items.where((i) => i.status == _QueueStatus.synced).length;

// ── Screen ────────────────────────────────────────────────────────────────────
class Day245OfflineSosUxScreen extends ConsumerStatefulWidget {
  const Day245OfflineSosUxScreen({super.key});

  @override
  ConsumerState<Day245OfflineSosUxScreen> createState() =>
      _Day245OfflineSosUxScreenState();
}

class _Day245OfflineSosUxScreenState
    extends ConsumerState<Day245OfflineSosUxScreen> {
  void _triggerOfflineSos() {
    if (!ref.read(_d245AirplaneModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable airplane mode simulation first.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final batch = ref.read(_d245DispatchCountProvider) + 1;
    final newItems = [
      _QueueItem(
        id: 'q_gps_$batch',
        type: _QueueType.gpsBatch,
        title: 'GPS batch · 8 points',
        detail: 'Offline SOS #$batch · queued locally',
        sizeKb: 3,
        queuedAt: now,
        status: _QueueStatus.pending,
      ),
      _QueueItem(
        id: 'q_ev_$batch',
        type: _QueueType.evidenceMeta,
        title: 'Evidence metadata',
        detail: 'Clip + hash · encrypted local vault',
        sizeKb: 96,
        queuedAt: now.add(const Duration(milliseconds: 200)),
        status: _QueueStatus.pending,
      ),
      _QueueItem(
        id: 'q_sms_$batch',
        type: _QueueType.smsAlert,
        title: 'SMS alert · Tier 1',
        detail: 'MSG91 payload · +91 98765 43210',
        sizeKb: 1,
        queuedAt: now.add(const Duration(milliseconds: 400)),
        status: _QueueStatus.pending,
      ),
      _QueueItem(
        id: 'q_push_$batch',
        type: _QueueType.pushAlert,
        title: 'Push · Trusted Circle',
        detail: 'FCM data message · 2 contacts',
        sizeKb: 2,
        queuedAt: now.add(const Duration(milliseconds: 600)),
        status: _QueueStatus.pending,
      ),
    ];

    ref.read(_d245QueueProvider.notifier).state = [
      ...ref.read(_d245QueueProvider),
      ...newItems,
    ];
    ref.read(_d245SosOfflineTriggeredProvider.notifier).state = true;
    ref.read(_d245DispatchCountProvider.notifier).state = batch;
    ref.read(_d245TabProvider.notifier).state = 1;

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'SOS captured offline — 4 items queued. Alerts send when signal returns.',
        ),
      ),
    );
  }

  Future<void> _flushQueue() async {
    if (ref.read(_d245AirplaneModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turn off airplane mode to flush queue.')),
      );
      return;
    }

    final pending = ref
        .read(_d245QueueProvider)
        .where((i) => i.status == _QueueStatus.pending)
        .toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing pending in queue.')),
      );
      return;
    }

    ref.read(_d245FlushingProvider.notifier).state = true;
    var queue = List<_QueueItem>.from(ref.read(_d245QueueProvider));

    for (var i = 0; i < pending.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      final id = pending[i].id;
      queue = queue
          .map(
            (item) => item.id == id
                ? item.copyWith(status: _QueueStatus.uploading)
                : item,
          )
          .toList();
      ref.read(_d245QueueProvider.notifier).state = queue;

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      queue = queue
          .map(
            (item) => item.id == id
                ? item.copyWith(status: _QueueStatus.synced)
                : item,
          )
          .toList();
      ref.read(_d245QueueProvider.notifier).state = queue;
    }

    ref.read(_d245FlushingProvider.notifier).state = false;
    ref.read(_d245LastFlushAtProvider.notifier).state = DateTime.now();
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pending.length} item(s) synced to backend (mock).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d245TabProvider);
    final airplane = ref.watch(_d245AirplaneModeProvider);
    final pending = _pendingCount(ref.watch(_d245QueueProvider));

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 245 · Offline SOS UX'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (airplane ? ZapColors.danger : ZapColors.safe)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (airplane ? ZapColors.danger : ZapColors.safe)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  airplane ? 'NO SIGNAL' : 'ONLINE',
                  style: TextStyle(
                    color: airplane ? ZapColors.danger : ZapColors.safe,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (airplane) _OfflineBanner(pendingCount: pending),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d245TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _SimulateTab(onTriggerOfflineSos: _triggerOfflineSos),
              1 => _QueueTab(onFlush: _flushQueue),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical: ZapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(color: ZapColors.danger.withOpacity(0.35)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.flight_rounded, color: ZapColors.danger, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'Airplane mode (simulated) · $pendingCount item(s) queued locally',
              style: const TextStyle(
                color: ZapColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Simulate ───────────────────────────────────────────────────────────
class _SimulateTab extends ConsumerWidget {
  const _SimulateTab({required this.onTriggerOfflineSos});

  final VoidCallback onTriggerOfflineSos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airplane = ref.watch(_d245AirplaneModeProvider);
    final triggered = ref.watch(_d245SosOfflineTriggeredProvider);
    final pending = _pendingCount(ref.watch(_d245QueueProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section C Day 5/20 · offline-first SOS dispatch queue',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withOpacity(0.18),
                _kAccent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SOS still works offline',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Recording, GPS capture, and evidence vault run on-device with no '
                'signal. Alerts and uploads queue locally — they send automatically '
                'when connectivity returns.',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: SwitchListTile(
            value: airplane,
            onChanged: (v) {
              ref.read(_d245AirplaneModeProvider.notifier).state = v;
              HapticFeedback.selectionClick();
            },
            secondary: Icon(
              airplane ? Icons.flight_rounded : Icons.signal_cellular_alt_rounded,
              color: airplane ? ZapColors.danger : ZapColors.safe,
            ),
            title: const Text(
              'Airplane mode simulation',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              airplane
                  ? 'No network — dispatches queue locally ($pending pending)'
                  : 'Connected — queue can flush to backend',
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
            activeColor: ZapColors.danger,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _StatusRow(
          icon: Icons.mic_rounded,
          label: 'On-device recording',
          status: 'Active',
          ok: true,
        ),
        _StatusRow(
          icon: Icons.my_location_rounded,
          label: 'GPS batch capture',
          status: airplane ? 'Queuing locally' : 'Streaming live',
          ok: true,
        ),
        _StatusRow(
          icon: Icons.cloud_off_rounded,
          label: 'Backend dispatch',
          status: airplane ? 'Waiting for signal' : 'Ready',
          ok: !airplane,
        ),
        _StatusRow(
          icon: Icons.sms_rounded,
          label: 'SMS / push alerts',
          status: airplane ? 'Queued ($pending)' : 'Can send now',
          ok: !airplane || pending > 0,
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: airplane ? onTriggerOfflineSos : null,
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Trigger SOS while offline'),
            style: FilledButton.styleFrom(
              backgroundColor: ZapColors.danger,
              disabledBackgroundColor: ZapColors.textMuted.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (triggered) ...[
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Offline SOS queued · open Queue tab · turn off airplane mode to flush',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kAccent.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.sosActive),
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: const Text('Day 76 · SOS Active (discreet mode)'),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String status;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: ok ? _kAccent : ZapColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: ok ? ZapColors.safe : ZapColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Queue ──────────────────────────────────────────────────────────────
class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.onFlush});

  final Future<void> Function() onFlush;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(_d245QueueProvider);
    final airplane = ref.watch(_d245AirplaneModeProvider);
    final flushing = ref.watch(_d245FlushingProvider);
    final lastFlush = ref.watch(_d245LastFlushAtProvider);
    final pending = _pendingCount(queue);
    final synced = _syncedCount(queue);

    final sorted = List<_QueueItem>.from(queue)
      ..sort((a, b) => b.queuedAt.compareTo(a.queuedAt));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Row(
          children: [
            _QueueStatChip(
              label: 'Pending',
              count: pending,
              color: ZapColors.warning,
            ),
            const SizedBox(width: ZapSpacing.sm),
            _QueueStatChip(
              label: 'Synced',
              count: synced,
              color: ZapColors.safe,
            ),
            const Spacer(),
            if (lastFlush != null)
              Text(
                'Last flush ${_kTimeFmt.format(lastFlush)}',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 9,
                ),
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (sorted.isEmpty)
          const Center(
            child: Text(
              'Queue empty — trigger offline SOS on Simulate tab.',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 12),
            ),
          )
        else
          ...sorted.map(
            (item) => _QueueItemTile(item: item, flushing: flushing),
          ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (airplane || flushing || pending == 0) ? null : onFlush,
            icon: flushing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(
              airplane
                  ? 'Offline — cannot flush'
                  : flushing
                      ? 'Uploading…'
                      : 'Flush queue now',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              disabledBackgroundColor: ZapColors.textMuted.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.offlineStatus),
          icon: const Icon(Icons.wifi_off_rounded, size: 18),
          label: const Text('Day 51 · Offline status'),
        ),
      ],
    );
  }
}

class _QueueStatChip extends StatelessWidget {
  const _QueueStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({required this.item, required this.flushing});

  final _QueueItem item;
  final bool flushing;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      _QueueStatus.pending => ZapColors.warning,
      _QueueStatus.uploading => _kAccent,
      _QueueStatus.synced => ZapColors.safe,
      _QueueStatus.failed => ZapColors.danger,
    };

    final statusLabel = switch (item.status) {
      _QueueStatus.pending => 'PENDING',
      _QueueStatus.uploading => 'UPLOADING',
      _QueueStatus.synced => 'SYNCED',
      _QueueStatus.failed => 'FAILED',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.status == _QueueStatus.uploading && flushing
              ? _kAccent
              : ZapColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.typeColor, size: 20),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  item.detail,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '${item.sizeKb} KB · queued ${_kTimeFmt.format(item.queuedAt)}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ─────────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airplane = ref.watch(_d245AirplaneModeProvider);
    final queue = ref.watch(_d245QueueProvider);
    final triggered = ref.watch(_d245SosOfflineTriggeredProvider);
    final dispatches = ref.watch(_d245DispatchCountProvider);
    final lastFlush = ref.watch(_d245LastFlushAtProvider);

    final payload = {
      'feature': 'offline_sos_ux',
      'version': '1.0.0',
      'section': 'C',
      'day': 245,
      'airplane_mode_simulated': airplane,
      'offline_sos_triggered': triggered,
      'dispatch_count': dispatches,
      'queue_pending': _pendingCount(queue),
      'queue_synced': _syncedCount(queue),
      'queue_items': queue.map((i) => i.toJson()).toList(),
      'last_flush_at': lastFlush?.toIso8601String(),
      'offline_status_route': AppRoutes.offlineStatus,
      'sos_active_route': AppRoutes.sosActive,
      'copy':
          'SOS still works offline — alerts send when signal returns',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Offline-first architecture · local queue + auto-retry',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'How offline SOS works',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.phone_android_rounded,
          title: 'Device keeps working',
          subtitle:
              'Mic, GPS, and encrypted vault operate with zero connectivity.',
        ),
        const _PolicyRow(
          icon: Icons.queue_rounded,
          title: 'Pending uploads list',
          subtitle:
              'GPS batches, evidence metadata, SMS, and push payloads queue locally.',
        ),
        const _PolicyRow(
          icon: Icons.sync_rounded,
          title: 'Auto-flush on reconnect',
          subtitle:
              'When signal returns, queue uploads in order (mock flush button).',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offline SOS JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy queue JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 251 Live Map'),
              onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            ),
            ActionChip(
              label: const Text('Day 250 Group Journey'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 249 Voice Assistants'),
              onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            ),
            ActionChip(
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 247 Haptic Patterns'),
              onPressed: () => context.push(AppRoutes.hapticPatterns),
            ),
            ActionChip(
              label: const Text('Day 246 Visual Alerts'),
              onPressed: () => context.push(AppRoutes.hearingImpairedVisual),
            ),
            ActionChip(
              label: const Text('Day 244 Fake Call'),
              onPressed: () => context.push(AppRoutes.fakeCallPolish),
            ),
            ActionChip(
              label: const Text('Day 51 Offline status'),
              onPressed: () => context.push(AppRoutes.offlineStatus),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZapColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
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
