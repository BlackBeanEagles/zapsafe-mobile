/// Day 294 — User Support Macros
///
/// Section E (Days 281-300): canned replies for common post-launch support
/// tickets — false positive SOS, billing disputes, and account deletion.
///
/// Tag: 🟢 FRONTEND-ONLY · clipboard macros · no ticket system integration.
///
/// Route: [AppRoutes.supportMacros] → `/support-macros`
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
const _kAccent = Color(0xFF0D9488);
const _kTabs = ['Macros', 'Compose', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kSupportEmail = 'support@zapsafe.app';

enum _MacroCategory { falsePositive, billing, deletion }

class _SupportMacro {
  const _SupportMacro({
    required this.id,
    required this.category,
    required this.title,
    required this.subject,
    required this.body,
    required this.sla,
    required this.tags,
  });

  final String id;
  final _MacroCategory category;
  final String title;
  final String subject;
  final String body;
  final String sla;
  final List<String> tags;
}

const _kMacros = [
  _SupportMacro(
    id: 'fp_accidental_sos',
    category: _MacroCategory.falsePositive,
    title: 'Accidental SOS — contacts alerted',
    subject: 'Re: Your ZapSafe SOS alert (ticket {{ticket_id}})',
    body: '''Hi {{name}},

Thank you for contacting ZapSafe support.

We reviewed ticket {{ticket_id}} and confirmed your SOS was triggered accidentally on {{date}}. Your trusted contacts may have received an alert notification.

What we did:
• Marked the session as a false positive in our logs
• Stopped any further notifications for that session

To prevent accidental triggers:
1. Open Settings → SOS Sensitivity and lower the shake threshold
2. Use the cancel PIN within 10 seconds if SOS starts unintentionally
3. Review Day 124 false-positive tuning in-app (Settings → Help)

If any contact is concerned, you can share that the alert was accidental. No emergency services were contacted.

Reply to this email if you need further help.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['SOS', 'false positive', 'contacts'],
  ),
  _SupportMacro(
    id: 'fp_no_alert_sent',
    category: _MacroCategory.falsePositive,
    title: 'False positive — no contacts notified',
    subject: 'ZapSafe SOS check — no alerts sent ({{ticket_id}})',
    body: '''Hi {{name}},

Thanks for reaching out about ticket {{ticket_id}}.

Our logs show the SOS session on {{date}} was cancelled before any contact notifications were sent. Your trusted circle was not alerted.

You are all set — no further action is required. If you see unexpected SOS prompts, try lowering sensitivity under Settings → SOS.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['SOS', 'cancelled', 'no alert'],
  ),
  _SupportMacro(
    id: 'fp_sensitivity_guide',
    category: _MacroCategory.falsePositive,
    title: 'Reduce false positives — sensitivity guide',
    subject: 'Tuning ZapSafe SOS sensitivity ({{ticket_id}})',
    body: '''Hi {{name}},

We understand accidental SOS triggers can be stressful. Here is how to tune ZapSafe for your device:

1. Settings → SOS Sensitivity → choose "Low" or "Custom"
2. Disable "Pocket mode" if you carry your phone in tight pockets
3. Run a drill (Home → Safety Drill) to verify cancel PIN muscle memory

Our target false-positive rate is < 0.5% of sessions (Day 292 war room gate). Your feedback helps us improve detection models.

Ticket {{ticket_id}} · logged {{date}}

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 8 h',
    tags: ['tuning', 'settings', 'drill'],
  ),
  _SupportMacro(
    id: 'bill_play_refund',
    category: _MacroCategory.billing,
    title: 'Google Play refund steps',
    subject: 'ZapSafe subscription refund — Play Store ({{ticket_id}})',
    body: '''Hi {{name}},

For ticket {{ticket_id}} regarding a ZapSafe Plus subscription:

Google Play handles all billing and refunds directly. ZapSafe cannot issue Play Store refunds from our side.

Steps:
1. Open play.google.com/store/account → Payments & subscriptions
2. Select ZapSafe → Request a refund (within 48 h of charge for fastest approval)
3. Or email Google Play support with your order ID from the receipt

We have not cancelled your account. After refund, Plus features expire at the end of the paid period.

Need your order ID? Settings → Billing History (Day 95) shows recent charges.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['Play Store', 'refund', 'Plus'],
  ),
  _SupportMacro(
    id: 'bill_restore_purchase',
    category: _MacroCategory.billing,
    title: 'Restore purchase — Plus not active',
    subject: 'Restore ZapSafe Plus purchase ({{ticket_id}})',
    body: '''Hi {{name}},

For ticket {{ticket_id}} — Plus features not showing after reinstall:

1. Sign in with the same account used for purchase ({{name}})
2. Settings → Subscription → Restore Purchases
3. Wait 60 seconds and pull-to-refresh on Home

If still inactive:
• Confirm the purchase email matches your ZapSafe login
• Send us your Play/App Store order ID from the receipt (not card number)

We will verify entitlement on our side within 24 h.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['restore', 'Plus', 'entitlement'],
  ),
  _SupportMacro(
    id: 'bill_unrecognized_charge',
    category: _MacroCategory.billing,
    title: 'Unrecognized charge dispute',
    subject: 'Billing inquiry — ticket {{ticket_id}}',
    body: '''Hi {{name}},

We received your billing inquiry (ticket {{ticket_id}}, {{date}}).

ZapSafe Plus is billed monthly or annually through Google Play or Apple App Store. Charges appear as "ZapSafe" or "Google ZapSafe" on statements.

To verify:
• Settings → Billing History shows your last 12 months
• Match the amount to Plus tier (see Day 95 pricing table)

If you do not recognize the charge:
1. Check if a family member shares your Play/App Store account
2. Dispute via your store's billing portal (fastest resolution)
3. Reply with last 4 digits of order ID only — never send full card numbers

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['dispute', 'charge', 'verify'],
  ),
  _SupportMacro(
    id: 'del_request_ack',
    category: _MacroCategory.deletion,
    title: 'Deletion request received (GDPR)',
    subject: 'Account deletion request confirmed ({{ticket_id}})',
    body: '''Hi {{name}},

We received your account deletion request under ticket {{ticket_id}} on {{date}}.

Timeline (Days 169-172 flow):
• Day 0: Request logged — account marked for deletion
• Days 1-14: Grace period — sign in to cancel deletion anytime
• Day 15: Permanent deletion of profile, contacts, and vault evidence

During grace period you can:
• Export your data: Settings → Privacy → Export (Day 167)
• Cancel deletion: Settings → Account → Cancel deletion request

We will email you at this address when deletion is complete.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['GDPR', 'grace', 'request'],
  ),
  _SupportMacro(
    id: 'del_grace_reminder',
    category: _MacroCategory.deletion,
    title: 'Grace period reminder — 7 days left',
    subject: 'ZapSafe account deletion — 7 days remaining',
    body: '''Hi {{name}},

Reminder for ticket {{ticket_id}}: your ZapSafe account is scheduled for permanent deletion in 7 days.

To keep your account: sign in and tap Cancel Deletion under Settings → Account (Day 170).

To proceed: no action needed. After deletion:
• Trusted contacts are removed
• Encrypted vault evidence is destroyed
• Subscription must be cancelled separately in Play/App Store

Questions? Reply before {{date}}.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['grace', 'reminder', 'cancel'],
  ),
  _SupportMacro(
    id: 'del_export_before_delete',
    category: _MacroCategory.deletion,
    title: 'Export data before deletion',
    subject: 'Download your ZapSafe data before deletion',
    body: '''Hi {{name}},

Before we complete deletion for ticket {{ticket_id}}, you can export your data:

1. Sign in during the 14-day grace period (Day 170)
2. Settings → Privacy → Export My Data (Day 167)
3. Download ZIP within 72 h — includes contacts list, journey history metadata, and settings JSON (vault audio excluded per encryption policy)

Export does not cancel deletion. To stop deletion, use Cancel Deletion in Settings → Account.

— ZapSafe Support
$_kSupportEmail''',
    sla: '< 4 h',
    tags: ['export', 'GDPR', 'ZIP'],
  ),
];

String _categoryLabel(_MacroCategory c) => switch (c) {
      _MacroCategory.falsePositive => 'False Positive',
      _MacroCategory.billing => 'Billing',
      _MacroCategory.deletion => 'Deletion',
    };

Color _categoryColor(_MacroCategory c) => switch (c) {
      _MacroCategory.falsePositive => const Color(0xFFF59E0B),
      _MacroCategory.billing => const Color(0xFF3B82F6),
      _MacroCategory.deletion => const Color(0xFFEF4444),
    };

String _categoryKey(_MacroCategory c) => switch (c) {
      _MacroCategory.falsePositive => 'false_positive',
      _MacroCategory.billing => 'billing',
      _MacroCategory.deletion => 'deletion',
    };

_SupportMacro? _macroById(String? id) {
  if (id == null) return null;
  for (final m in _kMacros) {
    if (m.id == id) return m;
  }
  return null;
}

String _renderMacro(
  _SupportMacro macro, {
  required String name,
  required String ticketId,
  required String date,
}) {
  return macro.body
      .replaceAll('{{name}}', name.isEmpty ? 'there' : name)
      .replaceAll('{{ticket_id}}', ticketId.isEmpty ? 'ZS-NEW' : ticketId)
      .replaceAll('{{date}}', date);
}

String _renderSubject(
  _SupportMacro macro, {
  required String name,
  required String ticketId,
  required String date,
}) {
  return macro.subject
      .replaceAll('{{name}}', name.isEmpty ? 'there' : name)
      .replaceAll('{{ticket_id}}', ticketId.isEmpty ? 'ZS-NEW' : ticketId)
      .replaceAll('{{date}}', date);
}

Map<String, dynamic> _macrosPayload({
  required String? selectedId,
  required String categoryFilter,
}) =>
    {
      'endpoint': 'GET /api/v1/support/macros/',
      'categories': ['false_positive', 'billing', 'deletion'],
      'macros_total': _kMacros.length,
      'selected_id': selectedId,
      'filter': categoryFilter,
      'sla_policy': 'billing_and_deletion_under_4h',
      'wire_note': 'Canned replies · placeholder merge · clipboard export',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d294TabProvider = StateProvider<int>((ref) => 0);
final _d294CategoryFilterProvider = StateProvider<String>((ref) => 'all');
final _d294SelectedMacroProvider =
    StateProvider<String?>((ref) => _kMacros.first.id);
final _d294CustomerNameProvider = StateProvider<String>((ref) => '');
final _d294TicketIdProvider = StateProvider<String>(
    (ref) => 'ZS-${DateTime.now().millisecondsSinceEpoch % 100000}');
final _d294SendingProvider = StateProvider<bool>((ref) => false);

List<_SupportMacro> _filteredMacros(String filter) {
  if (filter == 'all') return _kMacros;
  return _kMacros.where((m) => _categoryKey(m.category) == filter).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day294SupportMacrosScreen extends ConsumerWidget {
  const Day294SupportMacrosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d294CategoryFilterProvider);
    final count = _filteredMacros(filter).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 294 · Support Macros'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$count macros',
                  style: const TextStyle(
                    color: _kAccent,
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
            tab: ref.watch(_d294TabProvider),
            onSelect: (i) => ref.read(_d294TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d294TabProvider)) {
              0 => const _MacrosTab(),
              1 => const _ComposeTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Macros ─────────────────────────────────────────────────────────────
class _MacrosTab extends ConsumerWidget {
  const _MacrosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d294CategoryFilterProvider);
    final selected = ref.watch(_d294SelectedMacroProvider);
    final macros = _filteredMacros(filter);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Support macro library',
          subtitle: 'False positive · billing · deletion · tap to select',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: filter == 'all',
              onTap: () =>
                  ref.read(_d294CategoryFilterProvider.notifier).state = 'all',
            ),
            _FilterChip(
              label: 'False Positive',
              selected: filter == 'false_positive',
              color: _categoryColor(_MacroCategory.falsePositive),
              onTap: () => ref
                  .read(_d294CategoryFilterProvider.notifier)
                  .state = 'false_positive',
            ),
            _FilterChip(
              label: 'Billing',
              selected: filter == 'billing',
              color: _categoryColor(_MacroCategory.billing),
              onTap: () => ref
                  .read(_d294CategoryFilterProvider.notifier)
                  .state = 'billing',
            ),
            _FilterChip(
              label: 'Deletion',
              selected: filter == 'deletion',
              color: _categoryColor(_MacroCategory.deletion),
              onTap: () => ref
                  .read(_d294CategoryFilterProvider.notifier)
                  .state = 'deletion',
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ...macros.map((macro) {
          final isSelected = macro.id == selected;
          final color = _categoryColor(macro.category);
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: InkWell(
              onTap: () {
                ref.read(_d294SelectedMacroProvider.notifier).state = macro.id;
                ref.read(_d294TabProvider.notifier).state = 1;
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : ZapColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _categoryLabel(macro.category),
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'SLA ${macro.sla}',
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      macro.title,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      macro.body.split('\n').first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: macro.tags
                          .map(
                            (t) => Chip(
                              label: Text(t),
                              labelStyle: const TextStyle(fontSize: 9),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Tab 1: Compose ────────────────────────────────────────────────────────────
class _ComposeTab extends ConsumerStatefulWidget {
  const _ComposeTab();

  @override
  ConsumerState<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends ConsumerState<_ComposeTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ticketCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: ref.read(_d294CustomerNameProvider));
    _ticketCtrl = TextEditingController(text: ref.read(_d294TicketIdProvider));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ticketCtrl.dispose();
    super.dispose();
  }

  String get _dateStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMock(_SupportMacro macro, String fullReply) async {
    if (ref.read(_d294SendingProvider)) return;
    ref.read(_d294SendingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    ref.read(_d294SendingProvider.notifier).state = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mock reply sent for ${macro.title} (${macro.sla} SLA).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final macroId = ref.watch(_d294SelectedMacroProvider);
    final macro = _macroById(macroId) ?? _kMacros.first;
    final sending = ref.watch(_d294SendingProvider);
    final name = ref.watch(_d294CustomerNameProvider);
    final ticketId = ref.watch(_d294TicketIdProvider);

    final subject = _renderSubject(
      macro,
      name: name,
      ticketId: ticketId,
      date: _dateStr,
    );
    final body = _renderMacro(
      macro,
      name: name,
      ticketId: ticketId,
      date: _dateStr,
    );
    final fullReply = 'Subject: $subject\n\n$body';
    final color = _categoryColor(macro.category);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Compose reply',
          subtitle: 'Merge placeholders · copy · mock send',
        ),
        DropdownButtonFormField<String>(
          value: macro.id,
          decoration: const InputDecoration(
            labelText: 'Macro template',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: _kMacros
              .map(
                (m) => DropdownMenuItem(
                  value: m.id,
                  child: Text(
                    m.title,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              ref.read(_d294SelectedMacroProvider.notifier).state = v;
            }
          },
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Customer name',
            hintText: 'Priya',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) =>
              ref.read(_d294CustomerNameProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextField(
          controller: _ticketCtrl,
          decoration: const InputDecoration(
            labelText: 'Ticket ID',
            hintText: 'ZS-48291',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => ref.read(_d294TicketIdProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _categoryLabel(macro.category),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'SLA ${macro.sla}',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                'Subject: $subject',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const Divider(height: 16),
              SelectableText(
                body,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: fullReply));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reply copied to clipboard.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy full reply'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: sending ? null : () => _sendMock(macro, fullReply),
          icon: sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: const Text('Send mock reply'),
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
    final payload = _macrosPayload(
      selectedId: ref.watch(_d294SelectedMacroProvider),
      categoryFilter: ref.watch(_d294CategoryFilterProvider),
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Support macros',
          subtitle:
              'Post-launch canned replies · Day 292 war room SLA alignment.',
        ),
        const _PolicyRow(
          icon: Icons.warning_amber_rounded,
          title: 'False positive (3 macros)',
          subtitle:
              'Accidental SOS · no alert sent · sensitivity tuning · Day 115/124.',
        ),
        const _PolicyRow(
          icon: Icons.receipt_long_rounded,
          title: 'Billing (3 macros)',
          subtitle:
              'Play refund · restore purchase · charge dispute · Day 95/96.',
        ),
        const _PolicyRow(
          icon: Icons.delete_forever_rounded,
          title: 'Deletion (3 macros)',
          subtitle:
              'GDPR ack · grace reminder · export before delete · Day 169-172.',
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
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
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
              const SnackBar(content: Text('Macros spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
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
              label: const Text('Day 99 Help'),
              onPressed: () => context.push(AppRoutes.helpSupport),
            ),
            ActionChip(
              label: const Text('Day 124 FP Fix'),
              onPressed: () => context.push(AppRoutes.falsePositiveFix),
            ),
            ActionChip(
              label: const Text('Day 95 Billing'),
              onPressed: () => context.push(AppRoutes.billingHistory),
            ),
            ActionChip(
              label: const Text('Day 169 Deletion'),
              onPressed: () => context.push(AppRoutes.accountDeletionRequest),
            ),
            ActionChip(
              label: const Text('Day 292 War Room'),
              onPressed: () => context.push(AppRoutes.postLaunchMonitoring),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _kAccent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : ZapColors.textSecondary,
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
