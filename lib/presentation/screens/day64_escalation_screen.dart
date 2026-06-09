/// Day 64 — Escalation Policy Screen
///
/// • Create SOS escalation policies (POST /api/v1/escalation-policies/)
/// • List all policies — default shown with a badge at the top
/// • Edit (PATCH) each policy inline — timeouts, retries, final actions
/// • Activate a policy as default (POST /activate/)
/// • Delete a policy (DELETE)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/escalation_service.dart';
import '../../domain/providers/escalation_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day64EscalationScreen extends ConsumerStatefulWidget {
  const Day64EscalationScreen({super.key});

  @override
  ConsumerState<Day64EscalationScreen> createState() =>
      _Day64EscalationScreenState();
}

class _Day64EscalationScreenState
    extends ConsumerState<Day64EscalationScreen> {
  // ── Create-form state ──────────────────────────────────────────────────────
  final _createNameCtrl         = TextEditingController();
  final _createNotesCtrl        = TextEditingController();
  int   _createTier1Timeout     = 60;
  int   _createTier1Retry       = 2;
  int   _createTier2Timeout     = 120;
  bool  _createEscalateToTier2  = true;
  bool  _createAutoCallEmergency= false;
  bool  _createSendLocationSms  = true;
  bool  _createLoopAlarm        = false;
  bool  _createIsDefault        = false;
  bool  _creating               = false;
  String? _createError;
  String? _createSuccessName;

  // ── Edit state (keyed by policy id) ───────────────────────────────────────
  String?  _editingId;
  final    _editNameCtrl  = TextEditingController();
  final    _editNotesCtrl = TextEditingController();
  int?     _editTier1Timeout;
  int?     _editTier1Retry;
  int?     _editTier2Timeout;
  bool?    _editEscalateToTier2;
  bool?    _editAutoCallEmergency;
  bool?    _editSendLocationSms;
  bool?    _editLoopAlarm;
  bool     _saving    = false;
  String?  _saveError;
  bool     _deleting  = false;
  bool     _activating= false;

  @override
  void dispose() {
    _createNameCtrl.dispose();
    _createNotesCtrl.dispose();
    _editNameCtrl.dispose();
    _editNotesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _startEditing(EscalationPolicy p) {
    if (_editingId == p.id) {
      setState(() { _editingId = null; });
      return;
    }
    _editNameCtrl.text  = p.name;
    _editNotesCtrl.text = p.notes;
    setState(() {
      _editingId             = p.id;
      _editTier1Timeout      = p.tier1TimeoutSeconds;
      _editTier1Retry        = p.tier1RetryCount;
      _editTier2Timeout      = p.tier2TimeoutSeconds;
      _editEscalateToTier2   = p.escalateToTier2;
      _editAutoCallEmergency = p.autoCallEmergency;
      _editSendLocationSms   = p.sendLocationSms;
      _editLoopAlarm         = p.loopAudioAlarm;
      _saveError             = null;
    });
  }

  Future<void> _create() async {
    final name = _createNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() { _createError = 'Name is required.'; });
      return;
    }
    setState(() { _creating = true; _createError = null; _createSuccessName = null; });
    try {
      final created = await ref.read(escalationServiceProvider).create(
            name:                name,
            tier1TimeoutSeconds: _createTier1Timeout,
            tier1RetryCount:     _createTier1Retry,
            tier2TimeoutSeconds: _createTier2Timeout,
            isDefault:           _createIsDefault,
            escalateToTier2:     _createEscalateToTier2,
            autoCallEmergency:   _createAutoCallEmergency,
            sendLocationSms:     _createSendLocationSms,
            loopAudioAlarm:      _createLoopAlarm,
            notes:               _createNotesCtrl.text.trim(),
          );
      ref.invalidate(escalationPolicyListProvider);
      _createNameCtrl.clear();
      _createNotesCtrl.clear();
      setState(() {
        _createSuccessName     = created.name;
        _createTier1Timeout    = 60;
        _createTier1Retry      = 2;
        _createTier2Timeout    = 120;
        _createEscalateToTier2 = true;
        _createAutoCallEmergency = false;
        _createSendLocationSms = true;
        _createLoopAlarm       = false;
        _createIsDefault       = false;
      });
    } catch (e) {
      setState(() { _createError = e.toString(); });
    } finally {
      setState(() { _creating = false; });
    }
  }

  Future<void> _save() async {
    if (_editingId == null) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      await ref.read(escalationServiceProvider).update(
            _editingId!,
            name:                _editNameCtrl.text.trim().isEmpty
                                     ? null
                                     : _editNameCtrl.text.trim(),
            tier1TimeoutSeconds: _editTier1Timeout,
            tier1RetryCount:     _editTier1Retry,
            tier2TimeoutSeconds: _editTier2Timeout,
            escalateToTier2:     _editEscalateToTier2,
            autoCallEmergency:   _editAutoCallEmergency,
            sendLocationSms:     _editSendLocationSms,
            loopAudioAlarm:      _editLoopAlarm,
            notes:               _editNotesCtrl.text.trim(),
          );
      ref.invalidate(escalationPolicyListProvider);
      setState(() { _editingId = null; });
    } catch (e) {
      setState(() { _saveError = e.toString(); });
    } finally {
      setState(() { _saving = false; });
    }
  }

  Future<void> _activate(String id) async {
    setState(() { _activating = true; });
    try {
      await ref.read(escalationServiceProvider).activate(id);
      ref.invalidate(escalationPolicyListProvider);
    } catch (_) {}
    setState(() { _activating = false; });
  }

  Future<void> _delete(String id) async {
    setState(() { _deleting = true; });
    try {
      await ref.read(escalationServiceProvider).delete(id);
      ref.invalidate(escalationPolicyListProvider);
      setState(() { _editingId = null; _deleting = false; });
    } catch (e) {
      setState(() { _saveError = e.toString(); _deleting = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(escalationPolicyListProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Escalation Policies',
            style: ZapTypography.headlineSmall),
        elevation: 0,
      ),
      body: listAsync.when(
        loading: () => const _Spinner(),
        error:   (e, _) => Center(child: _ErrorBanner(e.toString())),
        data: (policies) => ListView(
          padding: const EdgeInsets.all(ZapSpacing.md),
          children: [
            // ── Create card ───────────────────────────────────────────────
            _CreateCard(
              nameCtrl:           _createNameCtrl,
              notesCtrl:          _createNotesCtrl,
              tier1Timeout:       _createTier1Timeout,
              tier1Retry:         _createTier1Retry,
              tier2Timeout:       _createTier2Timeout,
              escalateToTier2:    _createEscalateToTier2,
              autoCallEmergency:  _createAutoCallEmergency,
              sendLocationSms:    _createSendLocationSms,
              loopAlarm:          _createLoopAlarm,
              isDefault:          _createIsDefault,
              creating:           _creating,
              onTier1Timeout:  (v) => setState(() => _createTier1Timeout = v),
              onTier1Retry:    (v) => setState(() => _createTier1Retry = v),
              onTier2Timeout:  (v) => setState(() => _createTier2Timeout = v),
              onEscalateToTier2:(v)=> setState(() => _createEscalateToTier2 = v),
              onAutoCallEmergency:(v)=>setState(()=>_createAutoCallEmergency = v),
              onSendLocationSms:(v)=>setState(()=>_createSendLocationSms = v),
              onLoopAlarm:     (v) => setState(() => _createLoopAlarm = v),
              onIsDefault:     (v) => setState(() => _createIsDefault = v),
              onCreate: _create,
            ),
            if (_createError != null) ...[
              const SizedBox(height: ZapSpacing.xs),
              _ErrorBanner(_createError!),
            ],
            if (_createSuccessName != null) ...[
              const SizedBox(height: ZapSpacing.xs),
              _SuccessBanner('Created: "$_createSuccessName"'),
            ],
            const SizedBox(height: ZapSpacing.lg),

            // ── List ──────────────────────────────────────────────────────
            const _SectionLabel('YOUR POLICIES'),
            const SizedBox(height: ZapSpacing.md),

            if (policies.isEmpty)
              const _EmptyBox('No policies yet. Create one above.')
            else
              ...policies.map((p) => _PolicyCard(
                    policy:             p,
                    isEditing:          _editingId == p.id,
                    editNameCtrl:       _editNameCtrl,
                    editNotesCtrl:      _editNotesCtrl,
                    editTier1Timeout:   _editTier1Timeout,
                    editTier1Retry:     _editTier1Retry,
                    editTier2Timeout:   _editTier2Timeout,
                    editEscalateToTier2: _editEscalateToTier2,
                    editAutoCallEmergency: _editAutoCallEmergency,
                    editSendLocationSms: _editSendLocationSms,
                    editLoopAlarm:      _editLoopAlarm,
                    saving:             _saving,
                    deleting:           _deleting,
                    activating:         _activating,
                    saveError:          _editingId == p.id ? _saveError : null,
                    onTap:              () => _startEditing(p),
                    onTier1Timeout:  (v) => setState(() => _editTier1Timeout = v),
                    onTier1Retry:    (v) => setState(() => _editTier1Retry = v),
                    onTier2Timeout:  (v) => setState(() => _editTier2Timeout = v),
                    onEscalateToTier2:(v)=> setState(() => _editEscalateToTier2 = v),
                    onAutoCallEmergency:(v)=>setState(()=>_editAutoCallEmergency = v),
                    onSendLocationSms:(v)=>setState(()=>_editSendLocationSms = v),
                    onLoopAlarm:     (v) => setState(() => _editLoopAlarm = v),
                    onSave:     _save,
                    onActivate: () => _activate(p.id),
                    onDelete:   () => _delete(p.id),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Create card ──────────────────────────────────────────────────────────────

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.nameCtrl,
    required this.notesCtrl,
    required this.tier1Timeout,
    required this.tier1Retry,
    required this.tier2Timeout,
    required this.escalateToTier2,
    required this.autoCallEmergency,
    required this.sendLocationSms,
    required this.loopAlarm,
    required this.isDefault,
    required this.creating,
    required this.onTier1Timeout,
    required this.onTier1Retry,
    required this.onTier2Timeout,
    required this.onEscalateToTier2,
    required this.onAutoCallEmergency,
    required this.onSendLocationSms,
    required this.onLoopAlarm,
    required this.onIsDefault,
    required this.onCreate,
  });

  final TextEditingController nameCtrl;
  final TextEditingController notesCtrl;
  final int  tier1Timeout;
  final int  tier1Retry;
  final int  tier2Timeout;
  final bool escalateToTier2;
  final bool autoCallEmergency;
  final bool sendLocationSms;
  final bool loopAlarm;
  final bool isDefault;
  final bool creating;
  final ValueChanged<int>  onTier1Timeout;
  final ValueChanged<int>  onTier1Retry;
  final ValueChanged<int>  onTier2Timeout;
  final ValueChanged<bool> onEscalateToTier2;
  final ValueChanged<bool> onAutoCallEmergency;
  final ValueChanged<bool> onSendLocationSms;
  final ValueChanged<bool> onLoopAlarm;
  final ValueChanged<bool> onIsDefault;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.account_tree_rounded, size: 18, color: ZapColors.safe),
            SizedBox(width: ZapSpacing.xs),
            Text('New Escalation Policy', style: ZapTypography.labelMedium),
          ]),
          const SizedBox(height: ZapSpacing.md),

          // Name
          const _FieldLabel('Policy name *'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(controller: nameCtrl, hint: 'e.g. Night Mode, Default'),
          const SizedBox(height: ZapSpacing.md),

          // Tier 1 settings
          const _SectionLabel('TIER 1 — CONTACT ALERTS'),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: [
            Expanded(
              child: _StepperField(
                label:    'Timeout (s)',
                value:    tier1Timeout,
                min:      10,
                max:      600,
                step:     10,
                color:    ZapColors.warning,
                onChanged: onTier1Timeout,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _StepperField(
                label:    'Retry count',
                value:    tier1Retry,
                min:      0,
                max:      5,
                color:    ZapColors.info,
                onChanged: onTier1Retry,
              ),
            ),
          ]),
          const SizedBox(height: ZapSpacing.md),

          // Tier 2 toggle + timeout
          _ToggleRow(
            icon:  Icons.keyboard_double_arrow_up_rounded,
            color: ZapColors.warning,
            label: 'Escalate to tier 2',
            value: escalateToTier2,
            onChanged: onEscalateToTier2,
          ),
          if (escalateToTier2) ...[
            const SizedBox(height: ZapSpacing.sm),
            const _SectionLabel('TIER 2 — SECONDARY CONTACTS'),
            const SizedBox(height: ZapSpacing.sm),
            _StepperField(
              label:    'Tier 2 timeout (s)',
              value:    tier2Timeout,
              min:      10,
              max:      600,
              step:     10,
              color:    ZapColors.danger,
              onChanged: onTier2Timeout,
            ),
          ],
          const SizedBox(height: ZapSpacing.md),

          // Final actions
          const _SectionLabel('FINAL ACTIONS'),
          const SizedBox(height: ZapSpacing.sm),
          _ToggleRow(
            icon:  Icons.emergency_rounded,
            color: ZapColors.danger,
            label: 'Auto-call emergency (911)',
            value: autoCallEmergency,
            onChanged: onAutoCallEmergency,
          ),
          _ToggleRow(
            icon:  Icons.sms_rounded,
            color: ZapColors.info,
            label: 'Send location SMS',
            value: sendLocationSms,
            onChanged: onSendLocationSms,
          ),
          _ToggleRow(
            icon:  Icons.volume_up_rounded,
            color: ZapColors.warning,
            label: 'Loop audio alarm',
            value: loopAlarm,
            onChanged: onLoopAlarm,
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Set as default
          _ToggleRow(
            icon:  Icons.star_rounded,
            color: ZapColors.safe,
            label: 'Set as default on create',
            value: isDefault,
            onChanged: onIsDefault,
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Notes
          const _FieldLabel('Notes (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(controller: notesCtrl, hint: 'e.g. for overnight hours'),
          const SizedBox(height: ZapSpacing.md),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: creating ? null : onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.safe,
                foregroundColor: ZapColors.bgPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: creating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ZapColors.bgPrimary))
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(
                creating ? 'Creating…' : 'Create Policy',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.bgPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Policy card ──────────────────────────────────────────────────────────────

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.isEditing,
    required this.editNameCtrl,
    required this.editNotesCtrl,
    required this.editTier1Timeout,
    required this.editTier1Retry,
    required this.editTier2Timeout,
    required this.editEscalateToTier2,
    required this.editAutoCallEmergency,
    required this.editSendLocationSms,
    required this.editLoopAlarm,
    required this.saving,
    required this.deleting,
    required this.activating,
    required this.saveError,
    required this.onTap,
    required this.onTier1Timeout,
    required this.onTier1Retry,
    required this.onTier2Timeout,
    required this.onEscalateToTier2,
    required this.onAutoCallEmergency,
    required this.onSendLocationSms,
    required this.onLoopAlarm,
    required this.onSave,
    required this.onActivate,
    required this.onDelete,
  });

  final EscalationPolicy policy;
  final bool   isEditing;
  final TextEditingController editNameCtrl;
  final TextEditingController editNotesCtrl;
  final int?   editTier1Timeout;
  final int?   editTier1Retry;
  final int?   editTier2Timeout;
  final bool?  editEscalateToTier2;
  final bool?  editAutoCallEmergency;
  final bool?  editSendLocationSms;
  final bool?  editLoopAlarm;
  final bool   saving;
  final bool   deleting;
  final bool   activating;
  final String? saveError;
  final VoidCallback onTap;
  final ValueChanged<int>  onTier1Timeout;
  final ValueChanged<int>  onTier1Retry;
  final ValueChanged<int>  onTier2Timeout;
  final ValueChanged<bool> onEscalateToTier2;
  final ValueChanged<bool> onAutoCallEmergency;
  final ValueChanged<bool> onSendLocationSms;
  final ValueChanged<bool> onLoopAlarm;
  final VoidCallback onSave;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = policy;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEditing
                ? ZapColors.safe
                : p.isDefault
                    ? ZapColors.safe.withOpacity(0.4)
                    : ZapColors.bgElevated,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(p.name, style: ZapTypography.labelMedium),
                          if (p.isDefault) ...[
                            const SizedBox(width: ZapSpacing.xs),
                            _DefaultBadge(),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(
                          'T1: ${p.tier1TimeoutSeconds}s × ${p.tier1RetryCount}'
                          '${p.escalateToTier2 ? '  ·  T2: ${p.tier2TimeoutSeconds}s' : '  ·  no T2'}',
                          style: ZapTypography.labelSmall
                              .copyWith(color: ZapColors.textSecondary),
                        ),
                        if (p.autoCallEmergency || p.loopAudioAlarm)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(spacing: 4, children: [
                              if (p.autoCallEmergency)
                                const _MiniChip('911', ZapColors.danger),
                              if (p.loopAudioAlarm)
                                const _MiniChip('ALARM', ZapColors.warning),
                              if (!p.sendLocationSms)
                                const _MiniChip('no SMS', ZapColors.textSecondary),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isEditing
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: ZapColors.textSecondary,
                  ),
                ],
              ),
            ),

            // ── Edit panel ────────────────────────────────────────────────
            if (isEditing) ...[
              const Divider(height: 1, color: ZapColors.bgElevated),
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    const _FieldLabel('Policy name'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TextField(controller: editNameCtrl, hint: 'Policy name'),
                    const SizedBox(height: ZapSpacing.md),

                    // Tier 1
                    const _SectionLabel('TIER 1'),
                    const SizedBox(height: ZapSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: _StepperField(
                          label:    'Timeout (s)',
                          value:    editTier1Timeout ?? p.tier1TimeoutSeconds,
                          min:      10,
                          max:      600,
                          step:     10,
                          color:    ZapColors.warning,
                          onChanged: onTier1Timeout,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: _StepperField(
                          label:    'Retries',
                          value:    editTier1Retry ?? p.tier1RetryCount,
                          min:      0,
                          max:      5,
                          color:    ZapColors.info,
                          onChanged: onTier1Retry,
                        ),
                      ),
                    ]),
                    const SizedBox(height: ZapSpacing.sm),

                    // Tier 2
                    _ToggleRow(
                      icon:  Icons.keyboard_double_arrow_up_rounded,
                      color: ZapColors.warning,
                      label: 'Escalate to tier 2',
                      value: editEscalateToTier2 ?? p.escalateToTier2,
                      onChanged: onEscalateToTier2,
                    ),
                    if (editEscalateToTier2 ?? p.escalateToTier2) ...[
                      const SizedBox(height: ZapSpacing.xs),
                      _StepperField(
                        label:    'Tier 2 timeout (s)',
                        value:    editTier2Timeout ?? p.tier2TimeoutSeconds,
                        min:      10,
                        max:      600,
                        step:     10,
                        color:    ZapColors.danger,
                        onChanged: onTier2Timeout,
                      ),
                    ],
                    const SizedBox(height: ZapSpacing.sm),

                    // Final actions
                    const _SectionLabel('FINAL ACTIONS'),
                    const SizedBox(height: ZapSpacing.xs),
                    _ToggleRow(
                      icon:  Icons.emergency_rounded,
                      color: ZapColors.danger,
                      label: 'Auto-call emergency',
                      value: editAutoCallEmergency ?? p.autoCallEmergency,
                      onChanged: onAutoCallEmergency,
                    ),
                    _ToggleRow(
                      icon:  Icons.sms_rounded,
                      color: ZapColors.info,
                      label: 'Send location SMS',
                      value: editSendLocationSms ?? p.sendLocationSms,
                      onChanged: onSendLocationSms,
                    ),
                    _ToggleRow(
                      icon:  Icons.volume_up_rounded,
                      color: ZapColors.warning,
                      label: 'Loop audio alarm',
                      value: editLoopAlarm ?? p.loopAudioAlarm,
                      onChanged: onLoopAlarm,
                    ),
                    const SizedBox(height: ZapSpacing.sm),

                    // Notes
                    const _FieldLabel('Notes'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TextField(controller: editNotesCtrl, hint: 'Optional memo'),
                    if (saveError != null) ...[
                      const SizedBox(height: ZapSpacing.xs),
                      _ErrorBanner(saveError!),
                    ],
                    const SizedBox(height: ZapSpacing.sm),

                    // Buttons
                    Row(children: [
                      // Activate
                      if (!p.isDefault)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: activating ? null : onActivate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZapColors.safe,
                              foregroundColor: ZapColors.bgPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: activating
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ZapColors.bgPrimary))
                                : const Icon(Icons.star_rounded, size: 16),
                            label: Text(
                              activating ? '…' : 'Set Default',
                              style: ZapTypography.labelSmall
                                  .copyWith(color: ZapColors.bgPrimary),
                            ),
                          ),
                        ),
                      if (!p.isDefault) const SizedBox(width: ZapSpacing.xs),

                      // Save
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZapColors.info,
                            foregroundColor: ZapColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: saving
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ZapColors.textPrimary))
                              : const Icon(Icons.save_rounded, size: 16),
                          label: Text(saving ? 'Saving…' : 'Save',
                              style: ZapTypography.labelSmall),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.xs),

                      // Delete
                      OutlinedButton.icon(
                        onPressed: deleting ? null : onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZapColors.danger,
                          side: const BorderSide(color: ZapColors.danger),
                          padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: deleting
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ZapColors.danger))
                            : const Icon(Icons.delete_outline_rounded,
                                size: 16),
                        label: Text(deleting ? '…' : 'Delete',
                            style: ZapTypography.labelSmall),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ZapColors.safe.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('DEFAULT',
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.safe)),
      );
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.color);
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: ZapTypography.labelSmall.copyWith(color: color)),
      );
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
    this.step = 1,
  });
  final String label;
  final int    value;
  final int    min;
  final int    max;
  final int    step;
  final Color  color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: ZapSpacing.xs),
          Row(children: [
            _StepBtn(
              icon: Icons.remove,
              onTap: value - step >= min ? () => onChanged(value - step) : null,
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text('$value',
                style: ZapTypography.labelMedium.copyWith(color: color)),
            const SizedBox(width: ZapSpacing.sm),
            _StepBtn(
              icon: Icons.add,
              onTap: value + step <= max ? () => onChanged(value + step) : null,
            ),
          ]),
        ],
      );
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap != null
                ? ZapColors.bgElevated
                : ZapColors.bgElevated.withOpacity(0.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13,
              color: onTap != null
                  ? ZapColors.textSecondary
                  : ZapColors.textSecondary.withOpacity(0.4)),
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color    color;
  final String   label;
  final bool     value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: ZapSpacing.xs),
        Text(label, style: ZapTypography.bodySmall),
        const Spacer(),
        Switch(value: value, activeColor: color, onChanged: onChanged),
      ]);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall
            .copyWith(color: ZapColors.textSecondary),
      );
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, this.hint = ''});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style:      ZapTypography.bodySmall,
        decoration: InputDecoration(
          filled:    true,
          fillColor: ZapColors.bgElevated,
          hintText:  hint,
          hintStyle: ZapTypography.bodySmall
              .copyWith(color: ZapColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
        ),
        child: Text(message,
            style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
      );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.safe.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: ZapColors.safe),
          const SizedBox(width: ZapSpacing.xs),
          Expanded(
            child: Text(message,
                style:
                    ZapTypography.bodySmall.copyWith(color: ZapColors.safe)),
          ),
        ]),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: CircularProgressIndicator(
              color: ZapColors.safe, strokeWidth: 2),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
          child: Text(message,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary)),
        ),
      );
}
