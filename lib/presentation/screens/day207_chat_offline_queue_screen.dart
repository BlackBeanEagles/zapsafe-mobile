/// Day 207 — Live Chat Offline Queue
///
/// Section A (Days 201-220): counselor chat with offline message queue,
/// pending/synced/failed states, connectivity banner, app-bar queue counter.
///
/// Tag: 🟣 POLISH — mock connectivity_plus integration for live chat.
///
/// Route: [AppRoutes.chatOfflineQueue] → `/chat-offline-queue`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../data/services/connectivity_service.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum ChatMessageStatus { synced, pending, sending, failed }

enum MockChatConnectivity { online, offline }

class ChatQueueMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageStatus status;

  const ChatQueueMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.status,
  });

  ChatQueueMessage copyWith({ChatMessageStatus? status}) => ChatQueueMessage(
        id: id,
        text: text,
        isUser: isUser,
        timestamp: timestamp,
        status: status ?? this.status,
      );
}

List<ChatQueueMessage> _seedMessages() {
  final now = DateTime.now();
  return [
    ChatQueueMessage(
      id: 'm1',
      text: 'Hi — I\'m Priya from ZapSafe Support. How can I help you today?',
      isUser: false,
      timestamp: now.subtract(const Duration(minutes: 12)),
      status: ChatMessageStatus.synced,
    ),
    ChatQueueMessage(
      id: 'm2',
      text: 'I had a false alarm yesterday. Can you check my settings?',
      isUser: true,
      timestamp: now.subtract(const Duration(minutes: 11)),
      status: ChatMessageStatus.synced,
    ),
    ChatQueueMessage(
      id: 'm3',
      text:
          'Of course. I can see your DCS threshold is 0.75. I\'ll walk you '
          'through tuning it to reduce false positives.',
      isUser: false,
      timestamp: now.subtract(const Duration(minutes: 10)),
      status: ChatMessageStatus.synced,
    ),
  ];
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d207TabProvider = StateProvider<int>((ref) => 0);
final _d207ConnectivityProvider = StateProvider<MockChatConnectivity>(
  (ref) => MockChatConnectivity.online,
);
final _d207MessagesProvider = StateProvider<List<ChatQueueMessage>>(
  (ref) => _seedMessages(),
);
final _d207SimulateFailProvider = StateProvider<bool>((ref) => false);
final _d207FlushingProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Live Chat', 'Queue & Network', 'Spec'];

int _pendingCount(List<ChatQueueMessage> msgs) =>
    msgs.where((m) => m.status == ChatMessageStatus.pending).length;

int _failedCount(List<ChatQueueMessage> msgs) =>
    msgs.where((m) => m.status == ChatMessageStatus.failed).length;

// ── Screen ────────────────────────────────────────────────────────────────────
class Day207ChatOfflineQueueScreen extends ConsumerWidget {
  const Day207ChatOfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d207TabProvider);
    final pending = _pendingCount(ref.watch(_d207MessagesProvider));
    final failed = _failedCount(ref.watch(_d207MessagesProvider));
    final queueTotal = pending + failed;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 207 · Live Chat'),
        actions: [
          if (queueTotal > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Semantics(
                  label: '$queueTotal messages in queue',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: failed > 0
                          ? ZapColors.danger.withOpacity(0.15)
                          : ZapColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: failed > 0
                            ? ZapColors.danger.withOpacity(0.5)
                            : ZapColors.warning.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          failed > 0
                              ? Icons.error_outline_rounded
                              : Icons.schedule_send_rounded,
                          size: 14,
                          color: failed > 0 ? ZapColors.danger : ZapColors.warning,
                        ),
                        const SizedBox(width: ZapSpacing.xs),
                        Text(
                          '$queueTotal',
                          style: TextStyle(
                            color: failed > 0
                                ? ZapColors.danger
                                : ZapColors.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
            onSelect: (i) => ref.read(_d207TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LiveChatTab(),
              1 => const _QueueNetworkTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Chat ──────────────────────────────────────────────────────────
class _LiveChatTab extends ConsumerWidget {
  const _LiveChatTab();

  Future<void> _sendMessage(WidgetRef ref, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final online =
        ref.read(_d207ConnectivityProvider) == MockChatConnectivity.online;
    final id = 'm${DateTime.now().millisecondsSinceEpoch}';
    final msg = ChatQueueMessage(
      id: id,
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
      status: online ? ChatMessageStatus.sending : ChatMessageStatus.pending,
    );

    ref.read(_d207MessagesProvider.notifier).update((list) => [...list, msg]);

    if (!online) return;

    await _deliverMessage(ref, id);
  }

  Future<void> _deliverMessage(WidgetRef ref, String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final fail = ref.read(_d207SimulateFailProvider);
    ref.read(_d207MessagesProvider.notifier).update(
          (list) => list
              .map(
                (m) => m.id == id
                    ? m.copyWith(
                        status: fail
                            ? ChatMessageStatus.failed
                            : ChatMessageStatus.synced,
                      )
                    : m,
              )
              .toList(),
        );
  }

  Future<void> _retryMessage(WidgetRef ref, String id) async {
    if (ref.read(_d207ConnectivityProvider) == MockChatConnectivity.offline) {
      return;
    }
    ref.read(_d207MessagesProvider.notifier).update(
          (list) => list
              .map(
                (m) => m.id == id
                    ? m.copyWith(status: ChatMessageStatus.sending)
                    : m,
              )
              .toList(),
        );
    await _deliverMessage(ref, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(_d207MessagesProvider);
    final connectivity = ref.watch(_d207ConnectivityProvider);
    final pending = _pendingCount(messages);
    final isOffline = connectivity == MockChatConnectivity.offline;

    return Column(
      children: [
        if (isOffline) _ConnectivityBanner(pending: pending),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            itemCount: messages.length,
            itemBuilder: (context, i) => _MessageBubble(
              message: messages[i],
              onRetry: messages[i].status == ChatMessageStatus.failed
                  ? () => _retryMessage(ref, messages[i].id)
                  : null,
            ),
          ),
        ),
        _ChatInputBar(
          enabled: true,
          offlineHint: isOffline,
          onSend: (text) => _sendMessage(ref, text),
        ),
      ],
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  final int pending;

  const _ConnectivityBanner({required this.pending});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Offline. $pending messages will send when online.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical: ZapSpacing.md,
        ),
        color: ZapColors.warning.withOpacity(0.15),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: ZapColors.warning, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                pending > 0
                    ? 'Offline · $pending message${pending == 1 ? '' : 's'} '
                        'will send when online'
                    : 'Offline · messages will queue until you reconnect',
                style: const TextStyle(
                  color: ZapColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatQueueMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser ? ZapColors.safe.withOpacity(0.15) : ZapColors.bgCard;
    final border = isUser
        ? ZapColors.safe.withOpacity(0.35)
        : ZapColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Priya · Support',
                style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12).copyWith(
                bottomRight: isUser
                    ? const Radius.circular(4)
                    : const Radius.circular(12),
                bottomLeft: isUser
                    ? const Radius.circular(12)
                    : const Radius.circular(4),
              ),
              border: Border.all(color: border),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          _MessageStatusRow(message: message, onRetry: onRetry),
        ],
      ),
    );
  }
}

class _MessageStatusRow extends StatelessWidget {
  final ChatQueueMessage message;
  final VoidCallback? onRetry;

  const _MessageStatusRow({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (!message.isUser) {
      final time = TimeOfDay.fromDateTime(message.timestamp);
      final stamp =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      return Text(
        stamp,
        style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
      );
    }

    return switch (message.status) {
      ChatMessageStatus.synced => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 12, color: ZapColors.safe),
            SizedBox(width: ZapSpacing.xs),
            Text('Delivered',
                style: TextStyle(color: ZapColors.safe, fontSize: 10)),
          ],
        ),
      ChatMessageStatus.pending => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_send_rounded,
                size: 12, color: ZapColors.warning),
            SizedBox(width: ZapSpacing.xs),
            Text('Will send when online',
                style: TextStyle(color: ZapColors.warning, fontSize: 10)),
          ],
        ),
      ChatMessageStatus.sending => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ZapColors.info,
              ),
            ),
            SizedBox(width: 6),
            Text('Sending…',
                style: TextStyle(color: ZapColors.info, fontSize: 10)),
          ],
        ),
      ChatMessageStatus.failed => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 12, color: ZapColors.danger),
            const SizedBox(width: ZapSpacing.xs),
            const Text('Failed to send',
                style: TextStyle(color: ZapColors.danger, fontSize: 10)),
            if (onRetry != null) ...[
              const SizedBox(width: ZapSpacing.sm),
              Semantics(
                label: 'Retry sending message',
                button: true,
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ZapColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: ZapColors.danger.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: ZapColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
    };
  }
}

class _ChatInputBar extends StatefulWidget {
  final bool enabled;
  final bool offlineHint;
  final ValueChanged<String> onSend;

  const _ChatInputBar({
    required this.enabled,
    required this.offlineHint,
    required this.onSend,
  });

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSend(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.sm,
        ZapSpacing.lg,
        ZapSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: ZapColors.bgCard,
        border: Border(top: BorderSide(color: ZapColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.offlineHint)
            const Padding(
              padding: EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Text(
                'You can still type — message queues locally',
                style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Type a message to counselor',
                  textField: true,
                  child: TextField(
                    controller: _controller,
                    enabled: widget.enabled,
                    style: const TextStyle(color: ZapColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Message counselor…',
                      hintStyle: const TextStyle(color: ZapColors.textMuted),
                      filled: true,
                      fillColor: ZapColors.bgElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: ZapColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: ZapColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.lg,
                        vertical: ZapSpacing.md,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Semantics(
                label: 'Send message',
                button: true,
                child: Material(
                  color: ZapColors.safe,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: widget.enabled ? _submit : null,
                    borderRadius: BorderRadius.circular(28),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Queue & Network ────────────────────────────────────────────────────
class _QueueNetworkTab extends ConsumerWidget {
  const _QueueNetworkTab();

  Future<void> _flushQueue(WidgetRef ref) async {
    if (ref.read(_d207FlushingProvider)) return;
    ref.read(_d207FlushingProvider.notifier).state = true;

    final pending = ref
        .read(_d207MessagesProvider)
        .where((m) => m.status == ChatMessageStatus.pending)
        .map((m) => m.id)
        .toList();

    for (final id in pending) {
      ref.read(_d207MessagesProvider.notifier).update(
            (list) => list
                .map(
                  (m) => m.id == id
                      ? m.copyWith(status: ChatMessageStatus.sending)
                      : m,
                )
                .toList(),
          );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final fail = ref.read(_d207SimulateFailProvider) && id == pending.last;
      ref.read(_d207MessagesProvider.notifier).update(
            (list) => list
                .map(
                  (m) => m.id == id
                      ? m.copyWith(
                          status: fail
                              ? ChatMessageStatus.failed
                              : ChatMessageStatus.synced,
                        )
                      : m,
                )
                .toList(),
          );
    }

    ref.read(_d207FlushingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(_d207ConnectivityProvider);
    final messages = ref.watch(_d207MessagesProvider);
    final simulateFail = ref.watch(_d207SimulateFailProvider);
    final flushing = ref.watch(_d207FlushingProvider);
    final pending = _pendingCount(messages);
    final failed = _failedCount(messages);
    final isOnline = connectivity == MockChatConnectivity.online;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 7/20 · Mock connectivity_plus state',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _NetworkCard(
          isOnline: isOnline,
          type: isOnline ? ConnectivityType.wifi : ConnectivityType.none,
        ),
        const SizedBox(height: ZapSpacing.lg),
        SegmentedButton<MockChatConnectivity>(
          segments: const [
            ButtonSegment(
              value: MockChatConnectivity.online,
              label: Text('Online'),
              icon: Icon(Icons.wifi_rounded, size: 16),
            ),
            ButtonSegment(
              value: MockChatConnectivity.offline,
              label: Text('Offline'),
              icon: Icon(Icons.wifi_off_rounded, size: 16),
            ),
          ],
          selected: {connectivity},
          onSelectionChanged: (s) async {
            final next = s.first;
            ref.read(_d207ConnectivityProvider.notifier).state = next;
            if (next == MockChatConnectivity.online && pending > 0) {
              await _flushQueue(ref);
            }
          },
        ),
        const SizedBox(height: ZapSpacing.xl),
        _QueueStatsCard(pending: pending, failed: failed, flushing: flushing),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          value: simulateFail,
          onChanged: (v) =>
              ref.read(_d207SimulateFailProvider.notifier).state = v,
          activeColor: ZapColors.danger,
          title: const Text(
            'Simulate send failure',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Last queued message fails on flush (demo retry flow)',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Flush pending message queue',
          button: true,
          child: FilledButton.icon(
            onPressed: isOnline && pending > 0 && !flushing
                ? () => _flushQueue(ref)
                : null,
            icon: flushing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(flushing ? 'Sending queue…' : 'Flush queue now'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.safe,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Reset chat demo',
          button: true,
          child: OutlinedButton(
            onPressed: () {
              ref.read(_d207MessagesProvider.notifier).state = _seedMessages();
              ref.read(_d207ConnectivityProvider.notifier).state =
                  MockChatConnectivity.online;
              ref.read(_d207SimulateFailProvider.notifier).state = false;
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
            child: const Text('Reset demo'),
          ),
        ),
      ],
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final bool isOnline;
  final ConnectivityType type;

  const _NetworkCard({required this.isOnline, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? ZapColors.safe : ZapColors.danger;
    final label = switch (type) {
      ConnectivityType.wifi => 'WiFi · online',
      ConnectivityType.mobile => 'Mobile data · online',
      ConnectivityType.none => 'No connection',
    };

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: color,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isOnline
                      ? 'WebSocket wss://api.zapsafe.app/ws/chat/ connected'
                      : 'Messages queue in Hive until connectivity_plus '
                          'reports online',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
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

class _QueueStatsCard extends StatelessWidget {
  final int pending;
  final int failed;
  final bool flushing;

  const _QueueStatsCard({
    required this.pending,
    required this.failed,
    required this.flushing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatCell(
                label: 'Pending',
                value: '$pending',
                color: ZapColors.warning,
              ),
              _StatCell(
                label: 'Failed',
                value: '$failed',
                color: ZapColors.danger,
              ),
              _StatCell(
                label: 'Flushing',
                value: flushing ? 'Yes' : 'No',
                color: ZapColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Message states', 'synced · pending · sending · failed'),
      ('Offline send', 'User types freely · status = pending'),
      ('Connectivity banner', 'Shows when offline + queue count'),
      ('App bar counter', 'Pending + failed badge'),
      ('Auto flush', 'Going online drains pending queue'),
      ('Retry', 'Failed messages show Retry chip'),
      ('Storage', 'Hive box chat_outbox — survives app restart'),
      ('WebSocket', 'wss://api.zapsafe.app/ws/chat/ when online'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Live chat offline queue (Day 207 polish)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...rows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.$1,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  r.$2,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy integration snippet',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text:
                      'ref.watch(connectivityTypeProvider) → flush chat_outbox',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Snippet copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy integration snippet'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 209 — Loading states sweep (ZapSkeleton).',
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
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
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
