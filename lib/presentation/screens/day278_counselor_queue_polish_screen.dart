/// Day 278 — Counselor Queue UX Polish
///
/// Section D (Days 261-280): polished counselor chat with queue position,
/// estimated wait, and SOS context banner for incident follow-up.
///
/// Tag: 🟣 POLISH · extends Day 207 live chat queue concept.
///
/// Route: [AppRoutes.counselorQueuePolish] → `/counselor-queue-polish`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF8B5CF6);
const _kTabs = ['Chat', 'Queue', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _QueueState { waiting, connected }

class _CounselorMessage {
  const _CounselorMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.time,
  });

  final String id;
  final String text;
  final bool isUser;
  final String time;
}

const _kSeedMessages = [
  _CounselorMessage(
    id: 'sys1',
    text: 'You are in the counselor queue. A trained responder will join shortly.',
    isUser: false,
    time: '22:14',
  ),
  _CounselorMessage(
    id: 'u1',
    text: 'I triggered SOS earlier but cancelled within 30 seconds. I still feel uneasy.',
    isUser: true,
    time: '22:15',
  ),
];

int _etaMinutes(int position) => switch (position) {
      <= 1 => 2,
      2 => 5,
      3 => 8,
      _ => 12,
    };

Map<String, dynamic> _queuePayload({
  required _QueueState state,
  required int position,
  required bool sosContext,
  required int messageCount,
}) =>
    {
      'endpoint': 'GET /api/v1/counselor/queue/status/',
      'queue_state': state.name,
      'position': state == _QueueState.connected ? 0 : position,
      'estimated_wait_minutes':
          state == _QueueState.connected ? 0 : _etaMinutes(position),
      'sos_context_active': sosContext,
      'counselor_assigned': state == _QueueState.connected
          ? {'id': 'c_priya_04', 'name': 'Priya M.', 'badge': 'Trauma-informed'}
          : null,
      'message_count': messageCount,
      'polish_vs_day207': [
        'queue position + ETA strip',
        'SOS incident context banner',
        'counselor join animation mock',
      ],
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d278TabProvider = StateProvider<int>((ref) => 0);
final _d278QueueStateProvider =
    StateProvider<_QueueState>((ref) => _QueueState.waiting);
final _d278PositionProvider = StateProvider<int>((ref) => 4);
final _d278SosContextProvider = StateProvider<bool>((ref) => true);
final _d278MessagesProvider =
    StateProvider<List<_CounselorMessage>>((ref) => _kSeedMessages);
final _d278AdvancingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day278CounselorQueuePolishScreen extends ConsumerWidget {
  const Day278CounselorQueuePolishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d278QueueStateProvider);
    final position = ref.watch(_d278PositionProvider);
    final sosContext = ref.watch(_d278SosContextProvider);
    final advancing = ref.watch(_d278AdvancingProvider);

    String badge;
    if (state == _QueueState.connected) {
      badge = 'CONNECTED';
    } else if (advancing) {
      badge = 'MOVING…';
    } else if (sosContext) {
      badge = 'SOS · #$position';
    } else {
      badge = 'QUEUE #$position';
    }

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 278 · Counselor Queue'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (state == _QueueState.connected
                          ? ZapColors.safe
                          : sosContext
                              ? ZapColors.danger
                              : _kAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (state == _QueueState.connected
                            ? ZapColors.safe
                            : sosContext
                                ? ZapColors.danger
                                : _kAccent)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: state == _QueueState.connected
                        ? ZapColors.safe
                        : sosContext
                            ? ZapColors.danger
                            : _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
            tab: ref.watch(_d278TabProvider),
            onSelect: (i) => ref.read(_d278TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d278TabProvider)) {
              0 => const _ChatTab(),
              1 => const _QueueTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Chat ───────────────────────────────────────────────────────────────
class _ChatTab extends ConsumerWidget {
  const _ChatTab();

  Future<void> _sendMessage(WidgetRef ref, BuildContext context, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final msg = _CounselorMessage(
      id: 'u${DateTime.now().millisecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      time: TimeOfDay.now().format(context),
    );
    ref.read(_d278MessagesProvider.notifier).update((list) => [...list, msg]);

    if (ref.read(_d278QueueStateProvider) == _QueueState.connected) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      ref.read(_d278MessagesProvider.notifier).update(
            (list) => [
              ...list,
              const _CounselorMessage(
                id: 'c_auto',
                text:
                    'Thank you for sharing. Your SOS was resolved safely — let\'s '
                    'review what triggered the alert and adjust your settings.',
                isUser: false,
                time: 'now',
              ),
            ],
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d278QueueStateProvider);
    final position = ref.watch(_d278PositionProvider);
    final sosContext = ref.watch(_d278SosContextProvider);
    final messages = ref.watch(_d278MessagesProvider);
    final eta = _etaMinutes(position);

    return Column(
      children: [
        if (sosContext) const _SosContextBanner(),
        if (state == _QueueState.waiting)
          _QueueStrip(position: position, etaMinutes: eta),
        if (state == _QueueState.connected) const _ConnectedBanner(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            itemCount: messages.length,
            itemBuilder: (context, i) =>
                _MessageBubble(message: messages[i]),
          ),
        ),
        _ChatInputBar(
          hint: state == _QueueState.connected
              ? 'Message counselor…'
              : 'Queue message (sent when connected)…',
          onSend: (text) => _sendMessage(ref, context, text),
        ),
      ],
    );
  }
}

class _SosContextBanner extends StatelessWidget {
  const _SosContextBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(color: ZapColors.danger.withOpacity(0.35)),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.emergency_rounded, color: ZapColors.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS follow-up context',
                  style: TextStyle(
                    color: ZapColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Counselor sees: false alarm · HSR Layout · cancelled 22:12',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
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

class _QueueStrip extends StatelessWidget {
  const _QueueStrip({required this.position, required this.etaMinutes});

  final int position;
  final int etaMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
      color: _kAccent.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: _kAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Queue position $position',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Estimated wait ~$etaMinutes min · trauma-informed counselor',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#$position',
              style: const TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedBanner extends StatelessWidget {
  const _ConnectedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
      color: ZapColors.safe.withOpacity(0.1),
      child: const Row(
        children: [
          Icon(Icons.support_agent_rounded, color: ZapColors.safe, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Priya M. joined · trauma-informed counselor · SOS context loaded',
              style: TextStyle(
                color: ZapColors.safe,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _CounselorMessage message;

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isUser
        ? _kAccent.withOpacity(0.2)
        : ZapColors.bgCard;
    final border = message.isUser
        ? _kAccent.withOpacity(0.35)
        : ZapColors.border;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar({required this.hint, required this.onSend});

  final String hint;
  final ValueChanged<String> onSend;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: const BoxDecoration(
        color: ZapColors.bgCard,
        border: Border(top: BorderSide(color: ZapColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: ZapColors.bgPrimary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ZapColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ZapColors.border),
                ),
              ),
              onSubmitted: (text) {
                widget.onSend(text);
                _controller.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {
              widget.onSend(_controller.text);
              _controller.clear();
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            style: IconButton.styleFrom(backgroundColor: _kAccent),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Queue ──────────────────────────────────────────────────────────────
class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  Future<void> _advanceQueue(WidgetRef ref) async {
    if (ref.read(_d278QueueStateProvider) == _QueueState.connected) return;

    ref.read(_d278AdvancingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final pos = ref.read(_d278PositionProvider);
    if (pos <= 1) {
      ref.read(_d278QueueStateProvider.notifier).state = _QueueState.connected;
      ref.read(_d278PositionProvider.notifier).state = 0;
      ref.read(_d278MessagesProvider.notifier).update(
            (list) => [
              ...list,
              const _CounselorMessage(
                id: 'join',
                text:
                    'Hi, I\'m Priya — I can see your SOS was cancelled quickly. '
                    'You\'re safe now. Would you like to talk through what happened?',
                isUser: false,
                time: '22:18',
              ),
            ],
          );
    } else {
      ref.read(_d278PositionProvider.notifier).state = pos - 1;
    }
    ref.read(_d278AdvancingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d278QueueStateProvider);
    final position = ref.watch(_d278PositionProvider);
    final sosContext = ref.watch(_d278SosContextProvider);
    final advancing = ref.watch(_d278AdvancingProvider);
    final eta = state == _QueueState.connected ? 0 : _etaMinutes(position);
    final progress = state == _QueueState.connected
        ? 1.0
        : (4 - position) / 4.0;

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
            '🟣 POLISH · Section D Day 18/20 · queue position · ETA · SOS context banner',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: ZapColors.border,
                        color: state == _QueueState.connected
                            ? ZapColors.safe
                            : _kAccent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state == _QueueState.connected ? '✓' : '#$position',
                          style: TextStyle(
                            color: state == _QueueState.connected
                                ? ZapColors.safe
                                : ZapColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          state == _QueueState.connected
                              ? 'Connected'
                              : 'In queue',
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              Text(
                state == _QueueState.connected
                    ? 'Counselor connected'
                    : 'Estimated wait ~$eta minutes',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state == _QueueState.connected
                    ? 'Priya M. · trauma-informed · SOS context shared'
                    : '${position - 1} people ahead of you · avg handle 4 min',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'SOS context banner',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: const Text(
            'Show incident summary to counselor · mock from Day 76 flow',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          value: sosContext,
          activeColor: ZapColors.danger,
          onChanged: (v) => ref.read(_d278SosContextProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state == _QueueState.connected || advancing
                ? null
                : () => _advanceQueue(ref),
            icon: advancing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    state == _QueueState.connected
                        ? Icons.check_rounded
                        : Icons.fast_forward_rounded,
                    size: 16,
                  ),
            label: Text(
              state == _QueueState.connected
                  ? 'Counselor connected'
                  : advancing
                      ? 'Advancing queue…'
                      : 'Simulate queue advance',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Queue milestones',
          subtitle: 'Mock progression · position 4 → 1 → connected',
        ),
        ...[
          ('4', 'Joined queue', position < 4),
          ('3', 'Moved up', position <= 3 && state == _QueueState.waiting),
          ('2', 'Almost your turn', position <= 2 && state == _QueueState.waiting),
          ('1', 'Next in line', position <= 1 && state == _QueueState.waiting),
          ('✓', 'Counselor joined', state == _QueueState.connected),
        ].map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  step.$3 ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 16,
                  color: step.$3 ? ZapColors.safe : ZapColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  '${step.$1} · ${step.$2}',
                  style: TextStyle(
                    color: step.$3
                        ? ZapColors.textPrimary
                        : ZapColors.textMuted,
                    fontSize: 12,
                    fontWeight: step.$3 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d278QueueStateProvider);
    final position = ref.watch(_d278PositionProvider);
    final sosContext = ref.watch(_d278SosContextProvider);
    final messages = ref.watch(_d278MessagesProvider);
    final payload = _queuePayload(
      state: state,
      position: position,
      sosContext: sosContext,
      messageCount: messages.length,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.support_agent_rounded,
          title: 'Counselor queue polish',
          subtitle:
              'Queue position strip · estimated wait · SOS incident context banner '
              '· counselor join state · builds on Day 207 offline chat queue.',
        ),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'SOS context for counselors',
          subtitle:
              'When user arrives from SOS flow, counselor sees anonymized incident '
              'summary (location, outcome) without re-asking traumatic details.',
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
              const SnackBar(content: Text('Counselor queue spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy queue spec'),
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
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 207 Live Chat Queue'),
              onPressed: () => context.push(AppRoutes.chatOfflineQueue),
            ),
            ActionChip(
              label: const Text('Day 76 SOS Active'),
              onPressed: () => context.push(AppRoutes.sosActive),
            ),
            ActionChip(
              label: const Text('Day 99 Help & Support'),
              onPressed: () => context.push(AppRoutes.helpSupport),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
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
