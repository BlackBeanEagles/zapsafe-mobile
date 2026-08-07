/// Day 86 — Escalation Policy builder (v2).
///
/// Create, edit, delete, and activate escalation policies.
/// Each policy defines how the SOS alert chain progresses across tiers.
/// Visual flow diagram shows Tier 1 → timeout → Tier 2 → timeout → 112.
///
/// API: PATCH /api/v1/escalation-policies/<id>/ — Month 4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/escalation_providers_v2.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtSec(int s) {
  if (s < 60) { return '${s}s'; }
  return '${s ~/ 60}m';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day86EscalationPolicyScreen extends ConsumerWidget {
  const Day86EscalationPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(escalationPoliciesProvider);
    final defaultPolicy = policies.firstWhere(
      (p) => p.isDefault,
      orElse: () => policies.first,
    );

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: const Text(
          'Escalation Policies',
          style: ZapTypography.headlineSmall,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        backgroundColor: ZapColors.safe,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.lg, 100,
        ),
        children: [
          _ActiveBanner(policy: defaultPolicy),
          const SizedBox(height: ZapSpacing.md),
          ...policies.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _PolicyCard(
                policy:    p,
                canDelete: policies.length > 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet<void>(
      context:        ctx,
      isScrollControlled: true,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreatePolicySheet(),
    );
  }
}

// ─── Active banner ────────────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.policy});
  final EscalationPolicyV2 policy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.safe.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.safe.withOpacity(0.40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: ZapColors.safe, size: 20),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active policy: ${policy.name}',
                  style: ZapTypography.labelMedium.copyWith(color: ZapColors.safe),
                ),
                Text(
                  policy.flowSummary,
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
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

// ─── Policy card ─────────────────────────────────────────────────────────────

class _PolicyCard extends ConsumerStatefulWidget {
  const _PolicyCard({required this.policy, required this.canDelete});
  final EscalationPolicyV2 policy;
  final bool canDelete;

  @override
  ConsumerState<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends ConsumerState<_PolicyCard> {
  bool _expanded = false;
  bool _dirty    = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late int  _tier1Timeout;
  late int  _tier1Retry;
  late bool _escalateToTier2;
  late int  _tier2Timeout;
  late bool _autoCallEmergency;
  late bool _sendLocationSms;
  late bool _loopAudioAlarm;

  @override
  void initState() {
    super.initState();
    _load(widget.policy);
    _nameCtrl  = TextEditingController(text: widget.policy.name);
    _notesCtrl = TextEditingController(text: widget.policy.notes);
  }

  @override
  void didUpdateWidget(_PolicyCard old) {
    super.didUpdateWidget(old);
    if (!_dirty) {
      _load(widget.policy);
      _nameCtrl.text  = widget.policy.name;
      _notesCtrl.text = widget.policy.notes;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _load(EscalationPolicyV2 p) {
    _tier1Timeout      = p.tier1TimeoutSec;
    _tier1Retry        = p.tier1RetryCount;
    _escalateToTier2   = p.escalateToTier2;
    _tier2Timeout      = p.tier2TimeoutSec;
    _autoCallEmergency = p.autoCallEmergency;
    _sendLocationSms   = p.sendLocationSms;
    _loopAudioAlarm    = p.loopAudioAlarm;
  }

  void _markDirty() => setState(() { _dirty = true; });

  void _save() {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isEmpty) { return; }
    ref.read(escalationPoliciesProvider.notifier).update(
      widget.policy.copyWith(
        name:              trimmed,
        tier1TimeoutSec:   _tier1Timeout,
        tier1RetryCount:   _tier1Retry,
        escalateToTier2:   _escalateToTier2,
        tier2TimeoutSec:   _tier2Timeout,
        autoCallEmergency: _autoCallEmergency,
        sendLocationSms:   _sendLocationSms,
        loopAudioAlarm:    _loopAudioAlarm,
        notes:             _notesCtrl.text.trim(),
      ),
    );
    setState(() { _dirty = false; _expanded = false; });
  }

  void _cancel() {
    _load(widget.policy);
    _nameCtrl.text  = widget.policy.name;
    _notesCtrl.text = widget.policy.notes;
    setState(() { _dirty = false; _expanded = false; });
  }

  void _delete(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete policy?', style: ZapTypography.headlineSmall),
        content: Text(
          'Delete "${widget.policy.name}"? This cannot be undone.',
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              ref.read(escalationPoliciesProvider.notifier).delete(widget.policy.id);
            },
            child: Text(
              'Delete',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  EscalationPolicyV2 get _preview => widget.policy.copyWith(
    tier1TimeoutSec:   _tier1Timeout,
    tier1RetryCount:   _tier1Retry,
    escalateToTier2:   _escalateToTier2,
    tier2TimeoutSec:   _tier2Timeout,
    autoCallEmergency: _autoCallEmergency,
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.policy;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.isDefault
              ? ZapColors.safe.withOpacity(0.50)
              : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────────
          InkWell(
            onTap:        () => setState(() { _expanded = !_expanded; }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.lg,
                vertical:   ZapSpacing.md,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: p.isDefault
                          ? ZapColors.safe.withOpacity(0.15)
                          : ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_tree_rounded,
                      color: p.isDefault ? ZapColors.safe : ZapColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),

                  // Name + summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                style: ZapTypography.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (p.isDefault) ...[
                              const SizedBox(width: ZapSpacing.sm),
                              const _Chip(text: 'DEFAULT', color: ZapColors.safe),
                            ],
                            if (_dirty) ...[
                              const SizedBox(width: ZapSpacing.sm),
                              const _Chip(text: 'unsaved', color: ZapColors.warning),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.flowSummary,
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: ZapColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ─────────────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(color: ZapColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flow preview
                  const _SectionLabel('ESCALATION FLOW'),
                  const SizedBox(height: ZapSpacing.sm),
                  _FlowPreview(policy: _preview),
                  const SizedBox(height: ZapSpacing.lg),

                  // Name
                  const _SectionLabel('POLICY NAME'),
                  const SizedBox(height: ZapSpacing.sm),
                  _TextField(
                    controller: _nameCtrl,
                    hint:       'e.g. Night Mode',
                    onChanged:  (_) => _markDirty(),
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Tier 1 timeout
                  _DropdownRow(
                    label:   'TIER 1 TIMEOUT',
                    sublabel: 'Time before escalating to Tier 2',
                    value:   _tier1Timeout,
                    options: kTier1TimeoutOptions,
                    fmtVal:  _fmtSec,
                    onChanged: (v) { setState(() { _tier1Timeout = v; }); _markDirty(); },
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Tier 1 retry count
                  _StepperRow(
                    label:    'TIER 1 RETRIES',
                    sublabel: 'SMS attempts before escalating',
                    value:    _tier1Retry,
                    min:      1, max: 5,
                    onChanged: (v) { setState(() { _tier1Retry = v; }); _markDirty(); },
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Escalate to Tier 2
                  _BoolRow(
                    label:    'Escalate to Tier 2',
                    sublabel: 'Notify Tier 2 contacts if Tier 1 doesn\'t respond',
                    value:    _escalateToTier2,
                    onChanged: (v) {
                      setState(() { _escalateToTier2 = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // Tier 2 timeout (greyed when T2 off)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:  _escalateToTier2 ? 1.0 : 0.35,
                    child: IgnorePointer(
                      ignoring: !_escalateToTier2,
                      child: _DropdownRow(
                        label:    'TIER 2 TIMEOUT',
                        sublabel: 'Time before final escalation',
                        value:    _tier2Timeout,
                        options:  kTier2TimeoutOptions,
                        fmtVal:   _fmtSec,
                        onChanged: (v) {
                          setState(() { _tier2Timeout = v; });
                          _markDirty();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // Auto-call emergency
                  _BoolRow(
                    label:    'Auto-call 112',
                    sublabel: 'Dial emergency services if no contact responds',
                    value:    _autoCallEmergency,
                    accent:   _autoCallEmergency ? ZapColors.danger : null,
                    onChanged: (v) {
                      setState(() { _autoCallEmergency = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // Send location SMS
                  _BoolRow(
                    label:    'Send Location SMS',
                    sublabel: 'Include GPS coordinates in the alert message',
                    value:    _sendLocationSms,
                    onChanged: (v) {
                      setState(() { _sendLocationSms = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // Loop audio alarm
                  _BoolRow(
                    label:    'Loop Audio Alarm',
                    sublabel: 'Play siren repeatedly until dismissed',
                    value:    _loopAudioAlarm,
                    onChanged: (v) {
                      setState(() { _loopAudioAlarm = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Notes
                  const _SectionLabel('NOTES'),
                  const SizedBox(height: ZapSpacing.sm),
                  _TextField(
                    controller: _notesCtrl,
                    hint:       'Optional description…',
                    maxLines:   2,
                    onChanged:  (_) => _markDirty(),
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Action row
                  Row(
                    children: [
                      // Set as default
                      if (!p.isDefault)
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(escalationPoliciesProvider.notifier)
                              .setDefault(p.id),
                          icon:  const Icon(Icons.star_outline_rounded, size: 16),
                          label: const Text('Set Default'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZapColors.safe,
                            side: BorderSide(color: ZapColors.safe.withOpacity(0.50)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md, vertical: ZapSpacing.xs,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                      // Delete
                      if (widget.canDelete) ...[
                        const SizedBox(width: ZapSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => _delete(context),
                          icon:  const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZapColors.danger,
                            side: BorderSide(color: ZapColors.danger.withOpacity(0.50)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md, vertical: ZapSpacing.xs,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Save / Cancel
                      if (_dirty) ...[
                        TextButton(
                          onPressed: _cancel,
                          child: Text(
                            'Cancel',
                            style: ZapTypography.labelMedium
                                .copyWith(color: ZapColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZapColors.safe,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.lg, vertical: ZapSpacing.xs,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Flow preview ─────────────────────────────────────────────────────────────

class _FlowPreview extends StatelessWidget {
  const _FlowPreview({required this.policy});
  final EscalationPolicyV2 policy;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const _FlowNode(
            icon:  Icons.person_rounded,
            label: 'Tier 1',
            color: ZapColors.info,
          ),
          _FlowArrow(
            label: '${_fmtSec(policy.tier1TimeoutSec)} × ${policy.tier1RetryCount}',
          ),
          if (policy.escalateToTier2) ...[
            const _FlowNode(
              icon:  Icons.group_rounded,
              label: 'Tier 2',
              color: ZapColors.warning,
            ),
            _FlowArrow(label: _fmtSec(policy.tier2TimeoutSec)),
          ],
          if (policy.autoCallEmergency)
            const _FlowNode(
              icon:  Icons.local_phone_rounded,
              label: '112',
              color: ZapColors.danger,
            )
          else
            const _FlowNode(
              icon:  Icons.check_circle_outline_rounded,
              label: 'Done',
              color: ZapColors.textMuted,
            ),
        ],
      ),
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.15),
            shape:        BoxShape.circle,
            border:       Border.all(color: color.withOpacity(0.50)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          label,
          style: ZapTypography.bodySmall.copyWith(color: color, fontSize: 10),
        ),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(width: 16, height: 1, color: ZapColors.border),
            const Icon(Icons.arrow_forward_rounded, color: ZapColors.border, size: 16),
            Container(width: 4, height: 1, color: ZapColors.border),
          ],
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          label,
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textMuted, fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─── Create policy sheet ──────────────────────────────────────────────────────

class _CreatePolicySheet extends ConsumerStatefulWidget {
  const _CreatePolicySheet();

  @override
  ConsumerState<_CreatePolicySheet> createState() => _CreatePolicySheetState();
}

class _CreatePolicySheetState extends ConsumerState<_CreatePolicySheet> {
  final _nameCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();

  int  _tier1Timeout      = 60;
  int  _tier1Retry        = 2;
  bool _escalateToTier2   = true;
  int  _tier2Timeout      = 120;
  bool _autoCallEmergency = false;
  bool _sendLocationSms   = true;
  bool _loopAudioAlarm    = false;

  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  EscalationPolicyV2 get _preview => EscalationPolicyV2(
    id:                'preview',
    name:              _nameCtrl.text,
    isDefault:         false,
    tier1TimeoutSec:   _tier1Timeout,
    tier1RetryCount:   _tier1Retry,
    escalateToTier2:   _escalateToTier2,
    tier2TimeoutSec:   _tier2Timeout,
    autoCallEmergency: _autoCallEmergency,
    sendLocationSms:   _sendLocationSms,
    loopAudioAlarm:    _loopAudioAlarm,
    notes:             _notesCtrl.text,
  );

  void _create() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() { _nameError = 'Name is required'; });
      return;
    }
    final policy = EscalationPolicyV2(
      id:                'p${DateTime.now().millisecondsSinceEpoch}',
      name:              name,
      isDefault:         false,
      tier1TimeoutSec:   _tier1Timeout,
      tier1RetryCount:   _tier1Retry,
      escalateToTier2:   _escalateToTier2,
      tier2TimeoutSec:   _tier2Timeout,
      autoCallEmergency: _autoCallEmergency,
      sendLocationSms:   _sendLocationSms,
      loopAudioAlarm:    _loopAudioAlarm,
      notes:             _notesCtrl.text.trim(),
    );
    ref.read(escalationPoliciesProvider.notifier).add(policy);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.lg,
        ZapSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + ZapSpacing.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color:        ZapColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.lg),

            const Text('New Escalation Policy', style: ZapTypography.headlineSmall),
            const SizedBox(height: ZapSpacing.lg),

            // Live flow preview
            _FlowPreview(policy: _preview),
            const SizedBox(height: ZapSpacing.lg),

            // Name
            const _SectionLabel('POLICY NAME *'),
            const SizedBox(height: ZapSpacing.sm),
            _TextField(
              controller: _nameCtrl,
              hint:       'e.g. Night Mode',
              onChanged: (v) {
                setState(() { _nameError = null; });
              },
              errorText: _nameError,
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Tier 1 timeout
            _DropdownRow(
              label:    'TIER 1 TIMEOUT',
              sublabel: 'Time before escalating',
              value:    _tier1Timeout,
              options:  kTier1TimeoutOptions,
              fmtVal:   _fmtSec,
              onChanged: (v) => setState(() { _tier1Timeout = v; }),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Retry count
            _StepperRow(
              label:    'TIER 1 RETRIES',
              sublabel: 'SMS attempts',
              value:    _tier1Retry,
              min: 1, max: 5,
              onChanged: (v) => setState(() { _tier1Retry = v; }),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Escalate to T2
            _BoolRow(
              label:    'Escalate to Tier 2',
              sublabel: 'Notify Tier 2 contacts if Tier 1 doesn\'t respond',
              value:    _escalateToTier2,
              onChanged: (v) => setState(() { _escalateToTier2 = v; }),
            ),
            const SizedBox(height: ZapSpacing.md),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity:  _escalateToTier2 ? 1.0 : 0.35,
              child: IgnorePointer(
                ignoring: !_escalateToTier2,
                child: _DropdownRow(
                  label:    'TIER 2 TIMEOUT',
                  sublabel: 'Time before final escalation',
                  value:    _tier2Timeout,
                  options:  kTier2TimeoutOptions,
                  fmtVal:   _fmtSec,
                  onChanged: (v) => setState(() { _tier2Timeout = v; }),
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),

            _BoolRow(
              label:    'Auto-call 112',
              sublabel: 'Dial emergency services if no one responds',
              value:    _autoCallEmergency,
              accent:   _autoCallEmergency ? ZapColors.danger : null,
              onChanged: (v) => setState(() { _autoCallEmergency = v; }),
            ),
            const SizedBox(height: ZapSpacing.md),

            _BoolRow(
              label:    'Send Location SMS',
              sublabel: 'Include GPS coordinates in the alert',
              value:    _sendLocationSms,
              onChanged: (v) => setState(() { _sendLocationSms = v; }),
            ),
            const SizedBox(height: ZapSpacing.md),

            _BoolRow(
              label:    'Loop Audio Alarm',
              sublabel: 'Play siren repeatedly until dismissed',
              value:    _loopAudioAlarm,
              onChanged: (v) => setState(() { _loopAudioAlarm = v; }),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Notes
            const _SectionLabel('NOTES'),
            const SizedBox(height: ZapSpacing.sm),
            _TextField(
              controller: _notesCtrl,
              hint:       'Optional description…',
              maxLines:   2,
              onChanged:  (_) => setState(() {}),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZapColors.safe,
                  foregroundColor: Colors.white,
                  padding:         const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Create Policy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textSecondary, letterSpacing: 1.0,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: ZapTypography.bodySmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String                hint;
  final int                   maxLines;
  final void Function(String)? onChanged;
  final String?               errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style:      ZapTypography.bodyMedium,
      maxLines:   maxLines,
      onChanged:  onChanged,
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  ZapTypography.bodyMedium.copyWith(color: ZapColors.textMuted),
        errorText:  errorText,
        filled:     true,
        fillColor:  ZapColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: ZapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: ZapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: ZapColors.safe),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm,
        ),
      ),
    );
  }
}

class _BoolRow extends StatelessWidget {
  const _BoolRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.accent,
  });

  final String              label;
  final String              sublabel;
  final bool                value;
  final void Function(bool) onChanged;
  final Color?              accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ZapTypography.labelMedium.copyWith(
                  color: accent ?? ZapColors.textPrimary,
                ),
              ),
              Text(
                sublabel,
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              ),
            ],
          ),
        ),
        Switch(
          value:      value,
          onChanged:  onChanged,
          activeColor: accent ?? ZapColors.safe,
        ),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.options,
    required this.fmtVal,
    required this.onChanged,
  });

  final String          label;
  final String          sublabel;
  final int             value;
  final List<int>       options;
  final String Function(int) fmtVal;
  final void Function(int)   onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(label),
              Text(
                sublabel,
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              ),
            ],
          ),
        ),
        DropdownButton<int>(
          value:         value,
          dropdownColor: ZapColors.bgCard,
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
          underline:     const SizedBox.shrink(),
          items: options
              .map(
                (s) => DropdownMenuItem<int>(
                  value: s,
                  child: Text(fmtVal(s)),
                ),
              )
              .toList(),
          onChanged: (v) { if (v != null) { onChanged(v); } },
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String          label;
  final String          sublabel;
  final int             value;
  final int             min;
  final int             max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(label),
              Text(
                sublabel,
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepBtn(
              icon:      Icons.remove_rounded,
              enabled:   value > min,
              onPressed: () => onChanged(value - 1),
            ),
            SizedBox(
              width: 32,
              child: Text('$value', style: ZapTypography.labelLarge, textAlign: TextAlign.center),
            ),
            _StepBtn(
              icon:      Icons.add_rounded,
              enabled:   value < max,
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData     icon;
  final bool         enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color:        enabled ? ZapColors.bgSurface : ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: ZapColors.border),
        ),
        child: Icon(
          icon,
          size:  16,
          color: enabled ? ZapColors.textPrimary : ZapColors.textMuted,
        ),
      ),
    );
  }
}
