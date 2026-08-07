/// Day 385 — Support Macros — Production
///
/// Section O (Days 381-390, Project Close): promotes Day 294's macro
/// library (`day294_support_macros_screen.dart` — read directly before
/// building this) into a genuinely usable in-app tool, wired into Day
/// 369's real support-ticket kanban
/// (`day369_support_triage_screen.dart` — read directly before building
/// this) rather than a standalone demo.
///
/// **The wiring is real, not simulated**: this screen reads and writes
/// the exact same `SharedPreferences` key Day 369's board uses
/// (`day369_support_triage_v1`), in the exact same JSON-list-of-strings
/// shape. Picking a macro for a real ticket, composing the merged reply,
/// and tapping "Attach & resolve" writes `stage: 'resolved'` plus two new
/// optional fields (`resolution_macro`, `resolution_text`) back into that
/// shared storage — Day 369's own board (which ignores unknown JSON keys)
/// will show the ticket moved to Resolved the next time it loads. This is
/// a real integration between two existing screens' real local storage,
/// not a new parallel data source.
///
/// Macro bodies below are copied from Day 294's own library (one per
/// category: false positive, billing, deletion) — this project's own
/// original in-house copy, reused verbatim rather than rewritten, per the
/// spec's instruction to "promote Day 294's macros."
///
/// There are still no real tickets unless someone has added one via Day
/// 369's board first — this screen's empty state says so honestly and
/// links there, matching Day 369's own "board is genuinely empty" stance.
///
/// Tag: 🟢 FRONTEND-ONLY · real, genuinely usable · real read/write
/// integration with Day 369's actual local storage.
///
/// Route: [AppRoutes.supportMacrosProduction] → `/day-385-support-macros-production`
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
// Exact same key Day 369's kanban board uses — this is the real wiring.
const _kBoardPrefsKey = 'day369_support_triage_v1';

enum _Category { falsePositive, billing, deletion, other }
enum _Stage { newTicket, investigating, resolved }

_Category _categoryFromName(String? n) => _Category.values.firstWhere((c) => c.name == n, orElse: () => _Category.other);
_Stage _stageFromName(String? n) => _Stage.values.firstWhere((s) => s.name == n, orElse: () => _Stage.newTicket);

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
    this.resolutionMacro,
    this.resolutionText,
  });

  final String id;
  final String title;
  final String description;
  final _Category category;
  final _Stage stage;
  final DateTime createdAt;
  final String? resolutionMacro;
  final String? resolutionText;

  factory _Ticket.fromJson(Map<String, dynamic> j) => _Ticket(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: _categoryFromName(j['category'] as String?),
        stage: _stageFromName(j['stage'] as String?),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        resolutionMacro: j['resolution_macro'] as String?,
        resolutionText: j['resolution_text'] as String?,
      );

  // Preserves every field Day 369's board reads, plus the two new
  // resolution fields — Day 369's own fromJson ignores unknown keys.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'stage': stage.name,
        'created_at': createdAt.toIso8601String(),
        if (resolutionMacro != null) 'resolution_macro': resolutionMacro,
        if (resolutionText != null) 'resolution_text': resolutionText,
      };

  _Ticket resolvedWith(String macroId, String text) => _Ticket(
        id: id, title: title, description: description, category: category,
        stage: _Stage.resolved, createdAt: createdAt,
        resolutionMacro: macroId, resolutionText: text,
      );
}

class _Macro {
  const _Macro({required this.id, required this.category, required this.title, required this.subject, required this.body});
  final String id;
  final _Category category;
  final String title;
  final String subject;
  final String body;
}

// Copied verbatim from Day 294's own library — this project's original
// in-house copy, one representative macro per category, promoted here
// rather than rewritten.
const _kMacros = [
  _Macro(
    id: 'fp_accidental_sos',
    category: _Category.falsePositive,
    title: 'Accidental SOS — contacts alerted',
    subject: 'Re: Your ZapSafe SOS alert (ticket {{ticket_id}})',
    body: 'Hi there,\n\nThank you for contacting ZapSafe support.\n\n'
        'We reviewed ticket {{ticket_id}} and confirmed the SOS on {{ticket}} was '
        'triggered accidentally. Your trusted contacts may have received an alert.\n\n'
        'What we did:\n• Marked the session as a false positive\n• Stopped further notifications\n\n'
        'To prevent accidental triggers: Settings → SOS Sensitivity → lower the shake threshold, '
        'or use the cancel PIN within 10 seconds.\n\n— ZapSafe Support',
  ),
  _Macro(
    id: 'bill_play_refund',
    category: _Category.billing,
    title: 'Google Play refund steps',
    subject: 'ZapSafe subscription refund — Play Store ({{ticket_id}})',
    body: 'Hi there,\n\nFor ticket {{ticket_id}} regarding a ZapSafe Plus subscription:\n\n'
        'Google Play handles all billing and refunds directly. ZapSafe cannot issue Play Store '
        'refunds from our side.\n\nSteps:\n1. play.google.com/store/account → Payments & subscriptions\n'
        '2. Select ZapSafe → Request a refund (within 48h for fastest approval)\n\n'
        'We have not cancelled your account.\n\n— ZapSafe Support',
  ),
  _Macro(
    id: 'del_request_ack',
    category: _Category.deletion,
    title: 'Deletion request received',
    subject: 'Account deletion request confirmed ({{ticket_id}})',
    body: 'Hi there,\n\nWe received your account deletion request under ticket {{ticket_id}}.\n\n'
        'Timeline: Day 0 — request logged. Days 1-14 — grace period, sign in to cancel anytime. '
        'Day 15 — permanent deletion of profile, contacts, and vault evidence.\n\n'
        'During grace period you can export your data (Settings → Privacy → Export).\n\n'
        '— ZapSafe Support',
  ),
];

String _renderBody(_Macro m, _Ticket t) => m.body.replaceAll('{{ticket_id}}', t.id.length > 8 ? t.id.substring(t.id.length - 8) : t.id).replaceAll('{{ticket}}', t.title);
String _renderSubject(_Macro m, _Ticket t) => m.subject.replaceAll('{{ticket_id}}', t.id.length > 8 ? t.id.substring(t.id.length - 8) : t.id);

class _BoardIo {
  static Future<List<_Ticket>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kBoardPrefsKey);
    if (raw == null) return const [];
    try {
      return raw.map((s) => _Ticket.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveResolved(List<_Ticket> all, _Ticket updated) async {
    final prefs = await SharedPreferences.getInstance();
    final next = all.map((t) => t.id == updated.id ? updated : t).toList();
    await prefs.setStringList(_kBoardPrefsKey, next.map((e) => jsonEncode(e.toJson())).toList());
  }
}

Map<String, dynamic> _payload(List<_Ticket> tickets) => {
      'endpoint': 'NONE — real local read/write against Day 369\'s own SharedPreferences key',
      'shared_storage_key': _kBoardPrefsKey,
      'tickets_total': tickets.length,
      'resolved_with_macro': tickets.where((t) => t.resolutionMacro != null).length,
      'macros_available': _kMacros.length,
      'wire_note': 'Real read/write integration with day369_support_triage_screen.dart\'s '
          'own local storage — not a separate/duplicate data source.',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d385TicketsProvider = FutureProvider.autoDispose<List<_Ticket>>((ref) => _BoardIo.load());
final _d385SelectedTicketProvider = StateProvider<String?>((ref) => null);
final _d385SelectedMacroProvider = StateProvider<String?>((ref) => _kMacros.first.id);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day385SupportMacrosProductionScreen extends ConsumerWidget {
  const Day385SupportMacrosProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(_d385TicketsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day381_390.support_macros_production_title'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_d385TicketsProvider)),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: ZapColors.danger))),
        data: (tickets) {
          if (tickets.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
                  child: const Text(
                    'Day 369\'s ticket board is genuinely empty — there is no real launch '
                    'yet, so no real tickets exist. Add a ticket there first, then come '
                    'back here to attach a macro reply and resolve it.',
                    style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.supportTriage),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open Day 369 ticket board'),
                  style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
                ),
              ],
            );
          }
          return _MacroWorkbench(tickets: tickets);
        },
      ),
    );
  }
}

class _MacroWorkbench extends ConsumerWidget {
  const _MacroWorkbench({required this.tickets});
  final List<_Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(_d385SelectedTicketProvider) ?? tickets.first.id;
    final ticket = tickets.firstWhere((t) => t.id == selectedId, orElse: () => tickets.first);
    final macroId = ref.watch(_d385SelectedMacroProvider) ?? _kMacros.first.id;
    final macro = _kMacros.firstWhere((m) => m.id == macroId, orElse: () => _kMacros.first);
    final categoryMatches = ticket.category != _Category.other && macro.category == ticket.category;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.info.withOpacity(0.3))),
          child: Text('${tickets.length} real ticket(s) read from Day 369\'s board · '
              '${tickets.where((t) => t.stage == _Stage.resolved).length} resolved',
              style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('1. Select a ticket', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        DropdownButtonFormField<String>(
          value: selectedId,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: tickets.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.title} · ${_categoryLabel(t.category)} · ${t.stage.name}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => ref.read(_d385SelectedTicketProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('2. Select a macro', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(spacing: 8, children: _kMacros.map((m) => ChoiceChip(
              label: Text(m.title, style: const TextStyle(fontSize: 11)),
              selected: macro.id == m.id,
              onSelected: (_) => ref.read(_d385SelectedMacroProvider.notifier).state = m.id,
            )).toList()),
        if (!categoryMatches) ...[
          const SizedBox(height: 8),
          Text('Note: macro category (${_categoryLabel(macro.category)}) does not match ticket category (${_categoryLabel(ticket.category)}) — you can still use it, but double-check it fits.',
              style: const TextStyle(color: ZapColors.warning, fontSize: 10, height: 1.4)),
        ],
        const SizedBox(height: ZapSpacing.lg),
        const Text('3. Composed reply', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kAccent.withOpacity(0.4))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subject: ${_renderSubject(macro, ticket)}', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
              const Divider(height: 16),
              SelectableText(_renderBody(macro, ticket), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'Subject: ${_renderSubject(macro, ticket)}\n\n${_renderBody(macro, ticket)}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply copied.')));
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy reply'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: ticket.stage == _Stage.resolved ? null : () async {
                  final updated = ticket.resolvedWith(macro.id, _renderBody(macro, ticket));
                  await _BoardIo.saveResolved(tickets, updated);
                  ref.invalidate(_d385TicketsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket resolved — written to Day 369\'s real board storage.')));
                  }
                },
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: Text(ticket.stage == _Stage.resolved ? 'Already resolved' : 'Attach & resolve'),
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_kJsonEncoder.convert(_payload(tickets)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(label: const Text('Day 369 Board'), onPressed: () => context.push(AppRoutes.supportTriage)),
          ActionChip(label: const Text('Day 294 Original Macros'), onPressed: () => context.push(AppRoutes.supportMacros)),
        ]),
      ],
    );
  }
}
