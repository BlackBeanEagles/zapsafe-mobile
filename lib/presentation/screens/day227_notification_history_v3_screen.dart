/// Day 227 — Notification History Polish v2 (v3 screen)
///
/// Section B (Days 221-240): extends Day 88 history with SOS event grouping,
/// batch mark-read, and CSV export. Reuses [notifHistoryProvider] mock data.
///
/// Tag: 🟣 POLISH — no new API; builds on Day 88 v2 providers.
///
/// Route: [AppRoutes.notificationHistoryV3] → `/notification-history-v3`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/notification_history_providers_v2.dart';
import '../navigation/app_router.dart';

// ── Day 227 state ─────────────────────────────────────────────────────────────
final _d227TabProvider = StateProvider<int>((ref) => 0);
final _d227ReadIdsProvider = StateProvider<Set<String>>((ref) => {});
final _d227SelectedProvider = StateProvider<Set<String>>((ref) => {});
final _d227ExpandedSosProvider = StateProvider<Set<String>>((ref) => {'__all__'});

const _kTabs = ['Grouped', 'Batch Read', 'Export CSV'];

bool _isRead(NotifEntry entry, Set<String> readIds) =>
    readIds.contains(entry.id) || entry.ackedAt != null;

int _unreadCount(List<NotifEntry> entries, Set<String> readIds) =>
    entries.where((e) => !_isRead(e, readIds)).length;

List<({String? sosId, String label, List<NotifEntry> items})> _groupBySos(
  List<NotifEntry> entries,
) {
  final map = <String?, List<NotifEntry>>{};
  for (final e in entries) {
    map.putIfAbsent(e.sosEventId, () => []).add(e);
  }

  final groups = map.entries.map((e) {
    final label = e.key == null
        ? 'Other notifications'
        : 'SOS ${e.key}';
    e.value.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return (sosId: e.key, label: label, items: e.value);
  }).toList();

  groups.sort((a, b) {
    if (a.sosId == null) return 1;
    if (b.sosId == null) return -1;
    final aLatest = a.items.first.sentAt;
    final bLatest = b.items.first.sentAt;
    return bLatest.compareTo(aLatest);
  });

  return groups;
}

String _buildCsv(List<NotifEntry> entries, Set<String> readIds) {
  final buf = StringBuffer()
    ..writeln(
      'id,sos_event_id,channel,status,type,recipient,title,sent_at,read',
    );
  for (final e in entries) {
    final read = _isRead(e, readIds) ? 'true' : 'false';
    final sos = e.sosEventId ?? '';
    final sent = e.sentAt.toIso8601String();
    buf.writeln(
      '${e.id},"$sos",${e.channel.label},${e.status.label},'
      '${e.type.label},"${e.recipientName}","${e.title.replaceAll('"', "'")}",'
      '$sent,$read',
    );
  }
  return buf.toString();
}

String _fmtTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day227NotificationHistoryV3Screen extends ConsumerWidget {
  const Day227NotificationHistoryV3Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d227TabProvider);
    final entries = ref.watch(notifHistoryProvider);
    final readIds = ref.watch(_d227ReadIdsProvider);
    final unread = _unreadCount(entries, readIds);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 227 · Notification History v3'),
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZapColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: ZapColors.warning.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$unread unread',
                    style: const TextStyle(
                      color: ZapColors.warning,
                      fontSize: 10,
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
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d227TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _GroupedTab(),
              1 => const _BatchReadTab(),
              _ => const _ExportTab(),
            },
          ),
        ],
      ),
    );
  }
}

void _markRead(WidgetRef ref, Iterable<String> ids) {
  ref.read(_d227ReadIdsProvider.notifier).update((s) => {...s, ...ids});
}

void _toggleSelect(WidgetRef ref, String id) {
  ref.read(_d227SelectedProvider.notifier).update((s) {
    final next = {...s};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    return next;
  });
}

// ── Tab 0: Grouped by SOS ─────────────────────────────────────────────────────
class _GroupedTab extends ConsumerWidget {
  const _GroupedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(notifHistoryProvider);
    final readIds = ref.watch(_d227ReadIdsProvider);
    final expanded = ref.watch(_d227ExpandedSosProvider);
    final groups = _groupBySos(entries);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.info.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section B Day 7/20 · extends Day 88 · group by SOS event ID',
            style: TextStyle(color: ZapColors.info, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 88 v2'),
              onPressed: () => context.push(AppRoutes.notificationHistoryV2),
            ),
            ActionChip(
              label: Text('${groups.where((g) => g.sosId != null).length} SOS groups'),
              onPressed: null,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...groups.map((group) {
          final key = group.sosId ?? '__other__';
          final isExp =
              expanded.contains('__all__') || expanded.contains(key);
          final unread =
              _unreadCount(group.items, readIds);

          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: group.sosId != null
                    ? ZapColors.danger.withOpacity(0.35)
                    : ZapColors.border,
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => ref
                      .read(_d227ExpandedSosProvider.notifier)
                      .update((s) {
                    final next = {...s}..remove('__all__');
                    if (next.contains(key)) {
                      next.remove(key);
                    } else {
                      next.add(key);
                    }
                    return next;
                  }),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          group.sosId != null
                              ? Icons.sos_rounded
                              : Icons.notifications_rounded,
                          color: group.sosId != null
                              ? ZapColors.danger
                              : ZapColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.label,
                                style: const TextStyle(
                                  color: ZapColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${group.items.length} notifications'
                                '${unread > 0 ? ' · $unread unread' : ''}',
                                style: const TextStyle(
                                  color: ZapColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExp
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: ZapColors.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExp)
                  ...group.items.map(
                    (e) => _NotifRow(
                      entry: e,
                      read: _isRead(e, readIds),
                      onMarkRead: () => _markRead(ref, [e.id]),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _NotifRow extends StatelessWidget {
  final NotifEntry entry;
  final bool read;
  final VoidCallback onMarkRead;

  const _NotifRow({
    required this.entry,
    required this.read,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.md,
        0,
        ZapSpacing.md,
        ZapSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.type.icon, color: entry.status.color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: read
                        ? ZapColors.textMuted
                        : ZapColors.textPrimary,
                    fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 11,
                    decoration: read ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${entry.channel.label} · ${entry.recipientName} · '
                  '${_fmtTime(entry.sentAt)}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: entry.status),
          if (!read) ...[
            const SizedBox(width: ZapSpacing.xs),
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
              color: ZapColors.info,
              tooltip: 'Mark read',
              onPressed: onMarkRead,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final NotifStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status.color.withOpacity(0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Tab 1: Batch mark-read ────────────────────────────────────────────────────
class _BatchReadTab extends ConsumerWidget {
  const _BatchReadTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(notifHistoryProvider);
    final readIds = ref.watch(_d227ReadIdsProvider);
    final selected = ref.watch(_d227SelectedProvider);
    final unreadEntries =
        entries.where((e) => !_isRead(e, readIds)).toList();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Text(
          '${unreadEntries.length} unread · ${selected.length} selected',
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: unreadEntries.isEmpty
                    ? null
                    : () {
                        ref.read(_d227SelectedProvider.notifier).state =
                            unreadEntries.map((e) => e.id).toSet();
                      },
                child: const Text('Select all unread'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        ref.read(_d227SelectedProvider.notifier).state = {};
                      },
                child: const Text('Clear selection'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: selected.isEmpty
              ? null
              : () {
                  _markRead(ref, selected);
                  ref.read(_d227SelectedProvider.notifier).state = {};
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Marked ${selected.length} as read'),
                    ),
                  );
                },
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: Text(
            selected.isEmpty
                ? 'Mark selected as read'
                : 'Mark ${selected.length} as read',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.safe,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        FilledButton.icon(
          onPressed: unreadEntries.isEmpty
              ? null
              : () {
                  _markRead(ref, unreadEntries.map((e) => e.id));
                  ref.read(_d227SelectedProvider.notifier).state = {};
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Marked all ${unreadEntries.length} unread as read',
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.mark_email_read_rounded, size: 18),
          label: const Text('Mark all unread as read'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.info,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Divider(color: ZapColors.border),
        const SizedBox(height: ZapSpacing.sm),
        ...entries.map((e) {
          final read = _isRead(e, readIds);
          if (read) return const SizedBox.shrink();
          final sel = selected.contains(e.id);
          return CheckboxListTile(
            value: sel,
            onChanged: (_) => _toggleSelect(ref, e.id),
            activeColor: ZapColors.info,
            title: Text(
              e.title,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 12,
              ),
            ),
            subtitle: Text(
              e.sosEventId ?? 'No SOS ID · ${e.type.label}',
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
            secondary: Icon(e.channel.icon, color: e.channel.color, size: 20),
          );
        }),
      ],
    );
  }
}

// ── Tab 2: Export CSV ─────────────────────────────────────────────────────────
class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(notifHistoryProvider);
    final readIds = ref.watch(_d227ReadIdsProvider);
    final csv = _buildCsv(entries, readIds);
    final previewLines = csv.split('\n').take(8).join('\n');

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Export notification history',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          '${entries.length} rows · includes read state + SOS event ID',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            previewLines,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        if (entries.length > 7)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '… ${entries.length - 7} more rows in full export',
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy CSV export',
          button: true,
          child: FilledButton.icon(
            onPressed: entries.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${entries.length} rows as CSV'),
                      ),
                    );
                  },
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            label: const Text('Copy full CSV'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.warning,
            ),
          ),
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
            'Tomorrow: Day 231 — Stealth LP24 icon disguise setup.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
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
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? ZapColors.info
                            : Colors.transparent,
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
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
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
