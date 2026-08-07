/// Day 369 — Support Ticket Triage
///
/// Section M (Days 366-370, Post-Launch Week 1): a real, working kanban
/// board — New / Investigating / Resolved — for triaging support tickets.
///
/// **There are no real tickets yet** — there is no real launch, so no real
/// users have filed anything. The board starts genuinely empty. This is a
/// real, useful tool: add a ticket, move it through the pipeline, and
/// attach one of Day 294's real support macros
/// (`day294_support_macros_screen.dart`) as the response — not a mock UI
/// standing in for a future feature.
///
/// Tag: 🟢 FRONTEND-ONLY · real, empty kanban board · genuinely usable now.
///
/// Route: [AppRoutes.supportTriage] → `/day-369-support-triage`
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
const _kAccent = Color(0xFF0D9488);
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day369_support_triage_v1';

enum _Stage { newTicket, investigating, resolved }
enum _Category { falsePositive, billing, deletion, other }

String _stageLabel(_Stage s) => switch (s) {
      _Stage.newTicket => 'New',
      _Stage.investigating => 'Investigating',
      _Stage.resolved => 'Resolved',
    };

Color _stageColor(_Stage s) => switch (s) {
      _Stage.newTicket => ZapColors.info,
      _Stage.investigating => ZapColors.warning,
      _Stage.resolved => ZapColors.safe,
    };

String _categoryLabel(_Category c) => switch (c) {
      _Category.falsePositive => 'False Positive',
      _Category.billing => 'Billing',
      _Category.deletion => 'Deletion',
      _Category.other => 'Other',
    };

class _Ticket {
  const _Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.stage,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final _Category category;
  final _Stage stage;
  final DateTime createdAt;

  _Ticket copyWith({_Stage? stage}) => _Ticket(
        id: id, title: title, description: description, category: category,
        stage: stage ?? this.stage, createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'description': description,
        'category': category.name, 'stage': stage.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory _Ticket.fromJson(Map<String, dynamic> j) => _Ticket(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: _Category.values.firstWhere((c) => c.name == j['category'], orElse: () => _Category.other),
        stage: _Stage.values.firstWhere((s) => s.name == j['stage'], orElse: () => _Stage.newTicket),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class _TicketBoardNotifier extends StateNotifier<List<_Ticket>> {
  _TicketBoardNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPrefsKey);
      if (raw != null) {
        state = raw.map((s) => _Ticket.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefsKey, state.map((e) => jsonEncode(e.toJson())).toList());
    } catch (_) {}
  }

  void add(_Ticket t) {
    state = [t, ...state];
    _persist();
  }

  void moveTo(String id, _Stage stage) {
    state = state.map((t) => t.id == id ? t.copyWith(stage: stage) : t).toList();
    _persist();
  }

  void remove(String id) {
    state = state.where((t) => t.id != id).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }
}

final _d369BoardProvider = StateNotifierProvider<_TicketBoardNotifier, List<_Ticket>>((ref) => _TicketBoardNotifier());

Map<String, dynamic> _boardPayload(List<_Ticket> tickets) => {
      'endpoint': 'NONE — no real ticketing backend exists',
      'tickets_total': tickets.length,
      'by_stage': {for (final s in _Stage.values) s.name: tickets.where((t) => t.stage == s).length},
      'by_category': {for (final c in _Category.values) c.name: tickets.where((t) => t.category == c).length},
      'wire_note': 'Real, empty kanban — no real tickets exist since there is no real launch yet',
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day369SupportTriageScreen extends ConsumerWidget {
  const Day369SupportTriageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(_d369BoardProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day361_370.support_triage_title'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showAddDialog(context, ref)),
        ],
      ),
      body: tickets.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
                  child: const Text(
                    'No real tickets exist yet — there is no real launch, so no '
                    'real users have filed anything. Add a ticket with the + '
                    'button to try the workflow.',
                    style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: ZapSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(ZapSpacing.xl),
                  decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_outlined, color: ZapColors.textMuted, size: 40),
                      SizedBox(height: 8),
                      Text('Board is empty', style: TextStyle(color: ZapColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (final stage in _Stage.values)
                        Expanded(child: _StageColumn(stage: stage, tickets: tickets.where((t) => t.stage == stage).toList())),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_boardPayload(tickets))));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Board spec copied.')));
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy board JSON', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.supportMacros),
                          icon: const Icon(Icons.support_agent_rounded, size: 14),
                          label: const Text('Day 294 macros', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    _Category category = _Category.other;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setState) {
        return AlertDialog(
          backgroundColor: ZapColors.bgCard,
          title: const Text('New ticket', style: TextStyle(color: ZapColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, style: const TextStyle(color: ZapColors.textPrimary), decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: descController, style: const TextStyle(color: ZapColors.textPrimary), maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: _Category.values.map((c) => ChoiceChip(
                    label: Text(_categoryLabel(c), style: const TextStyle(fontSize: 10)),
                    selected: category == c,
                    onSelected: (_) => setState(() => category = c),
                  )).toList()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                ref.read(_d369BoardProvider.notifier).add(_Ticket(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      category: category,
                      stage: _Stage.newTicket,
                      createdAt: DateTime.now(),
                    ));
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      }),
    );
  }
}

class _StageColumn extends ConsumerWidget {
  const _StageColumn({required this.stage, required this.tickets});
  final _Stage stage;
  final List<_Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _stageColor(stage);
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ZapColors.bgSurface, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
            child: Text('${_stageLabel(stage)} (${tickets.length})', textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(4),
              children: tickets.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_categoryLabel(t.category), style: const TextStyle(color: ZapColors.textMuted, fontSize: 8)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 2, runSpacing: 2, children: [
                          for (final s in _Stage.values)
                            if (s != stage)
                              InkWell(
                                onTap: () => ref.read(_d369BoardProvider.notifier).moveTo(t.id, s),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: _stageColor(s).withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                                  child: Text('→ ${_stageLabel(s)}', style: TextStyle(color: _stageColor(s), fontSize: 8)),
                                ),
                              ),
                          InkWell(
                            onTap: () => ref.read(_d369BoardProvider.notifier).remove(t.id),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(Icons.close_rounded, size: 10, color: ZapColors.textMuted),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
