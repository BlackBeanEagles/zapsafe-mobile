/// Day 63 — Alert Threshold Screen
///
/// • Create per-model SOS trigger rules (POST /api/v1/alert-thresholds/)
/// • List existing rules with is_active filter
/// • Edit (PATCH) each rule inline — confidence, latency cap, consecutive
///   triggers, cooldown, auto-SOS, notify-contacts, active toggle
/// • Delete a rule (DELETE)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/alert_threshold_service.dart';
import '../../domain/providers/alert_threshold_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day63AlertThresholdScreen extends ConsumerStatefulWidget {
  const Day63AlertThresholdScreen({super.key});

  @override
  ConsumerState<Day63AlertThresholdScreen> createState() =>
      _Day63AlertThresholdScreenState();
}

class _Day63AlertThresholdScreenState
    extends ConsumerState<Day63AlertThresholdScreen> {
  // ── Create-form state ──────────────────────────────────────────────────────
  AlertModelType _createModelType   = AlertModelType.scream;
  double  _createConfidence         = 0.75;
  double? _createMaxLatencyMs;          // null = no limit
  int     _createConsecutive        = 1;
  int     _createCooldown           = 30;
  bool    _createAutoSos            = false;
  bool    _createNotifyContacts     = true;
  final   _createNotesCtrl          = TextEditingController();
  bool    _creating                 = false;
  String? _createError;
  String? _createSuccessId;

  // ── Filter ─────────────────────────────────────────────────────────────────
  String _filterActive = '';   // '' | 'true' | 'false'

  // ── Edit state (keyed by threshold id) ────────────────────────────────────
  String?  _editingId;
  double?  _editConfidence;
  double?  _editMaxLatencyMs;
  int?     _editConsecutive;
  int?     _editCooldown;
  bool?    _editAutoSos;
  bool?    _editNotifyContacts;
  final    _editNotesCtrl = TextEditingController();
  bool     _saving        = false;
  String?  _saveError;
  bool     _deleting      = false;

  @override
  void dispose() {
    _createNotesCtrl.dispose();
    _editNotesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _startEditing(AlertThreshold t) {
    if (_editingId == t.id) {
      setState(() { _editingId = null; });
      return;
    }
    _editNotesCtrl.text = t.notes;
    setState(() {
      _editingId          = t.id;
      _editConfidence     = t.minConfidence;
      _editMaxLatencyMs   = t.maxLatencyMs;
      _editConsecutive    = t.consecutiveTriggers;
      _editCooldown       = t.cooldownSeconds;
      _editAutoSos        = t.autoSos;
      _editNotifyContacts = t.notifyContacts;
      _saveError          = null;
    });
  }

  Future<void> _create(List<AlertThreshold> existing) async {
    // Guard: can't create if model type already has a threshold
    if (existing.any((t) => t.modelType == _createModelType.value)) {
      setState(() {
        _createError =
            '${_createModelType.label} already has a threshold. '
            'Expand it below to edit.';
      });
      return;
    }
    setState(() { _creating = true; _createError = null; _createSuccessId = null; });
    try {
      final created = await ref.read(alertThresholdServiceProvider).create(
            modelType:          _createModelType.value,
            minConfidence:      _createConfidence,
            maxLatencyMs:       _createMaxLatencyMs,
            consecutiveTriggers: _createConsecutive,
            cooldownSeconds:    _createCooldown,
            autoSos:            _createAutoSos,
            notifyContacts:     _createNotifyContacts,
            notes:              _createNotesCtrl.text.trim(),
          );
      ref.invalidate(alertThresholdListProvider);
      _createNotesCtrl.clear();
      setState(() {
        _createSuccessId   = created.id;
        _createConfidence  = 0.75;
        _createMaxLatencyMs = null;
        _createConsecutive = 1;
        _createCooldown    = 30;
        _createAutoSos     = false;
        _createNotifyContacts = true;
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
      await ref.read(alertThresholdServiceProvider).update(
            _editingId!,
            minConfidence:      _editConfidence,
            maxLatencyMs:       _editMaxLatencyMs,
            consecutiveTriggers: _editConsecutive,
            cooldownSeconds:    _editCooldown,
            autoSos:            _editAutoSos,
            notifyContacts:     _editNotifyContacts,
            notes:              _editNotesCtrl.text.trim(),
          );
      ref.invalidate(alertThresholdListProvider);
      setState(() { _editingId = null; });
    } catch (e) {
      setState(() { _saveError = e.toString(); });
    } finally {
      setState(() { _saving = false; });
    }
  }

  Future<void> _toggleActive(AlertThreshold t) async {
    setState(() { _deleting = false; });
    try {
      await ref.read(alertThresholdServiceProvider).update(
            t.id,
            isActive: !t.isActive,
          );
      ref.invalidate(alertThresholdListProvider);
    } catch (_) {}
  }

  Future<void> _delete(String id) async {
    setState(() { _deleting = true; });
    try {
      await ref.read(alertThresholdServiceProvider).delete(id);
      ref.invalidate(alertThresholdListProvider);
      setState(() { _editingId = null; _deleting = false; });
    } catch (e) {
      setState(() { _saveError = e.toString(); _deleting = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(alertThresholdListProvider(_filterActive));

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Alert Thresholds',
            style: ZapTypography.headlineSmall),
        elevation: 0,
      ),
      body: listAsync.when(
        loading: () => const _Spinner(),
        error:   (e, _) => Center(child: _ErrorBanner(e.toString())),
        data: (thresholds) => ListView(
          padding: const EdgeInsets.all(ZapSpacing.md),
          children: [
            // ── Create card ───────────────────────────────────────────────
            _CreateCard(
              modelType:       _createModelType,
              confidence:      _createConfidence,
              maxLatencyMs:    _createMaxLatencyMs,
              consecutive:     _createConsecutive,
              cooldown:        _createCooldown,
              autoSos:         _createAutoSos,
              notifyContacts:  _createNotifyContacts,
              notesCtrl:       _createNotesCtrl,
              creating:        _creating,
              onModelType:     (v) => setState(() => _createModelType = v),
              onConfidence:    (v) => setState(() => _createConfidence = v),
              onMaxLatencyMs:  (v) => setState(() => _createMaxLatencyMs = v),
              onConsecutive:   (v) => setState(() => _createConsecutive = v),
              onCooldown:      (v) => setState(() => _createCooldown = v),
              onAutoSos:       (v) => setState(() => _createAutoSos = v),
              onNotifyContacts: (v) => setState(() => _createNotifyContacts = v),
              onCreate: () => _create(thresholds),
            ),
            if (_createError != null) ...[
              const SizedBox(height: ZapSpacing.xs),
              _ErrorBanner(_createError!),
            ],
            if (_createSuccessId != null) ...[
              const SizedBox(height: ZapSpacing.xs),
              _SuccessBanner(
                  'Created! ID: ${_createSuccessId!.substring(0, 8)}…'),
            ],
            const SizedBox(height: ZapSpacing.lg),

            // ── Filter + list ─────────────────────────────────────────────
            const _SectionLabel('YOUR THRESHOLDS'),
            const SizedBox(height: ZapSpacing.sm),
            _ActiveFilterChips(
              selected: _filterActive,
              onSelect: (v) =>
                  setState(() { _filterActive = v; _editingId = null; }),
            ),
            const SizedBox(height: ZapSpacing.md),

            if (thresholds.isEmpty)
              const _EmptyBox('No thresholds yet. Create one above.')
            else
              ...thresholds.map((t) => _ThresholdCard(
                    threshold:      t,
                    isEditing:      _editingId == t.id,
                    editConfidence: _editConfidence,
                    editMaxLatencyMs: _editMaxLatencyMs,
                    editConsecutive:  _editConsecutive,
                    editCooldown:     _editCooldown,
                    editAutoSos:      _editAutoSos,
                    editNotifyContacts: _editNotifyContacts,
                    editNotesCtrl:    _editNotesCtrl,
                    saving:    _saving,
                    deleting:  _deleting,
                    saveError: _editingId == t.id ? _saveError : null,
                    onTap:     () => _startEditing(t),
                    onConfidence:    (v) => setState(() => _editConfidence = v),
                    onMaxLatencyMs:  (v) => setState(() => _editMaxLatencyMs = v),
                    onConsecutive:   (v) => setState(() => _editConsecutive = v),
                    onCooldown:      (v) => setState(() => _editCooldown = v),
                    onAutoSos:       (v) => setState(() => _editAutoSos = v),
                    onNotifyContacts:(v) => setState(() => _editNotifyContacts = v),
                    onSave:   _save,
                    onToggle: () => _toggleActive(t),
                    onDelete: () => _delete(t.id),
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
    required this.modelType,
    required this.confidence,
    required this.maxLatencyMs,
    required this.consecutive,
    required this.cooldown,
    required this.autoSos,
    required this.notifyContacts,
    required this.notesCtrl,
    required this.creating,
    required this.onModelType,
    required this.onConfidence,
    required this.onMaxLatencyMs,
    required this.onConsecutive,
    required this.onCooldown,
    required this.onAutoSos,
    required this.onNotifyContacts,
    required this.onCreate,
  });

  final AlertModelType modelType;
  final double  confidence;
  final double? maxLatencyMs;
  final int     consecutive;
  final int     cooldown;
  final bool    autoSos;
  final bool    notifyContacts;
  final TextEditingController notesCtrl;
  final bool    creating;
  final ValueChanged<AlertModelType> onModelType;
  final ValueChanged<double>  onConfidence;
  final ValueChanged<double?> onMaxLatencyMs;
  final ValueChanged<int>     onConsecutive;
  final ValueChanged<int>     onCooldown;
  final ValueChanged<bool>    onAutoSos;
  final ValueChanged<bool>    onNotifyContacts;
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
            Icon(Icons.tune_rounded, size: 18, color: ZapColors.warning),
            SizedBox(width: ZapSpacing.xs),
            Text('New Threshold Rule', style: ZapTypography.labelMedium),
          ]),
          const SizedBox(height: ZapSpacing.md),

          // Model type
          const _FieldLabel('Model type'),
          const SizedBox(height: ZapSpacing.xs),
          _ModelTypeDropdown(value: modelType, onChanged: onModelType),
          const SizedBox(height: ZapSpacing.md),

          // Confidence slider
          _SliderRow(
            label:    'Min confidence',
            valueStr: confidence.toStringAsFixed(2),
            valueColor: _confColor(confidence),
            child: Slider(
              value:      confidence,
              min:        0.0,
              max:        1.0,
              divisions:  100,
              activeColor: _confColor(confidence),
              onChanged:  onConfidence,
            ),
          ),

          // Max latency
          _LatencyRow(
            value:     maxLatencyMs,
            onChanged: onMaxLatencyMs,
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Consecutive + Cooldown
          Row(children: [
            Expanded(
              child: _StepperField(
                label:    'Consecutive',
                value:    consecutive,
                min:      1,
                max:      10,
                color:    ZapColors.info,
                onChanged: onConsecutive,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _StepperField(
                label:    'Cooldown (s)',
                value:    cooldown,
                min:      0,
                max:      3600,
                step:     10,
                color:    ZapColors.safe,
                onChanged: onCooldown,
              ),
            ),
          ]),
          const SizedBox(height: ZapSpacing.sm),

          // Toggles
          _ToggleRow(
            icon:  Icons.sos_rounded,
            color: ZapColors.danger,
            label: 'Auto-SOS',
            value: autoSos,
            onChanged: onAutoSos,
          ),
          _ToggleRow(
            icon:  Icons.notifications_active_rounded,
            color: ZapColors.warning,
            label: 'Notify contacts',
            value: notifyContacts,
            onChanged: onNotifyContacts,
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Notes
          const _FieldLabel('Notes (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(controller: notesCtrl, hint: 'e.g. high-sensitivity for night mode'),
          const SizedBox(height: ZapSpacing.md),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: creating ? null : onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.warning,
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
                creating ? 'Creating…' : 'Create Rule',
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

// ─── Threshold card ───────────────────────────────────────────────────────────

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    required this.threshold,
    required this.isEditing,
    required this.editConfidence,
    required this.editMaxLatencyMs,
    required this.editConsecutive,
    required this.editCooldown,
    required this.editAutoSos,
    required this.editNotifyContacts,
    required this.editNotesCtrl,
    required this.saving,
    required this.deleting,
    required this.saveError,
    required this.onTap,
    required this.onConfidence,
    required this.onMaxLatencyMs,
    required this.onConsecutive,
    required this.onCooldown,
    required this.onAutoSos,
    required this.onNotifyContacts,
    required this.onSave,
    required this.onToggle,
    required this.onDelete,
  });

  final AlertThreshold threshold;
  final bool   isEditing;
  final double? editConfidence;
  final double? editMaxLatencyMs;
  final int?    editConsecutive;
  final int?    editCooldown;
  final bool?   editAutoSos;
  final bool?   editNotifyContacts;
  final TextEditingController editNotesCtrl;
  final bool    saving;
  final bool    deleting;
  final String? saveError;
  final VoidCallback onTap;
  final ValueChanged<double>  onConfidence;
  final ValueChanged<double?> onMaxLatencyMs;
  final ValueChanged<int>     onConsecutive;
  final ValueChanged<int>     onCooldown;
  final ValueChanged<bool>    onAutoSos;
  final ValueChanged<bool>    onNotifyContacts;
  final VoidCallback onSave;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = threshold;
    final typeColor = _modelColor(t.modelType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEditing ? typeColor : ZapColors.bgElevated,
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
                  _ModelBadge(t.modelType),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'conf ≥ ${t.minConfidence.toStringAsFixed(2)}'
                          '${t.maxLatencyMs != null ? '  ·  ≤${t.maxLatencyMs!.toStringAsFixed(0)} ms' : ''}',
                          style: ZapTypography.labelSmall
                              .copyWith(color: ZapColors.textSecondary),
                        ),
                        Text(
                          '${t.consecutiveTriggers}× hits  ·  ${t.cooldownSeconds}s cooldown',
                          style: ZapTypography.labelSmall
                              .copyWith(color: ZapColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Active toggle chip
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.isActive
                            ? ZapColors.safe.withOpacity(0.15)
                            : ZapColors.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.isActive ? 'Active' : 'Off',
                        style: ZapTypography.labelSmall.copyWith(
                          color: t.isActive
                              ? ZapColors.safe
                              : ZapColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.xs),
                  // Auto-SOS badge
                  if (t.autoSos)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ZapColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('AUTO-SOS',
                          style: ZapTypography.labelSmall
                              .copyWith(color: ZapColors.danger)),
                    ),
                  const SizedBox(width: ZapSpacing.xs),
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
                    // Confidence
                    _SliderRow(
                      label: 'Min confidence',
                      valueStr: (editConfidence ?? t.minConfidence)
                          .toStringAsFixed(2),
                      valueColor:
                          _confColor(editConfidence ?? t.minConfidence),
                      child: Slider(
                        value: editConfidence ?? t.minConfidence,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        activeColor:
                            _confColor(editConfidence ?? t.minConfidence),
                        onChanged: onConfidence,
                      ),
                    ),

                    // Max latency
                    _LatencyRow(
                      value: editMaxLatencyMs ?? t.maxLatencyMs,
                      onChanged: onMaxLatencyMs,
                    ),
                    const SizedBox(height: ZapSpacing.sm),

                    // Consecutive + Cooldown
                    Row(children: [
                      Expanded(
                        child: _StepperField(
                          label: 'Consecutive',
                          value: editConsecutive ?? t.consecutiveTriggers,
                          min:   1,
                          max:   10,
                          color: ZapColors.info,
                          onChanged: onConsecutive,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: _StepperField(
                          label: 'Cooldown (s)',
                          value: editCooldown ?? t.cooldownSeconds,
                          min:   0,
                          max:   3600,
                          step:  10,
                          color: ZapColors.safe,
                          onChanged: onCooldown,
                        ),
                      ),
                    ]),
                    const SizedBox(height: ZapSpacing.sm),

                    // Toggles
                    _ToggleRow(
                      icon:  Icons.sos_rounded,
                      color: ZapColors.danger,
                      label: 'Auto-SOS',
                      value: editAutoSos ?? t.autoSos,
                      onChanged: onAutoSos,
                    ),
                    _ToggleRow(
                      icon:  Icons.notifications_active_rounded,
                      color: ZapColors.warning,
                      label: 'Notify contacts',
                      value: editNotifyContacts ?? t.notifyContacts,
                      onChanged: onNotifyContacts,
                    ),
                    const SizedBox(height: ZapSpacing.sm),

                    // Notes
                    const _FieldLabel('Notes'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TextField(
                        controller: editNotesCtrl, hint: 'Optional memo'),
                    if (saveError != null) ...[
                      const SizedBox(height: ZapSpacing.xs),
                      _ErrorBanner(saveError!),
                    ],
                    const SizedBox(height: ZapSpacing.sm),

                    // Action buttons
                    Row(children: [
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
                      const SizedBox(width: ZapSpacing.sm),
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

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _ModelTypeDropdown extends StatelessWidget {
  const _ModelTypeDropdown({
    required this.value,
    required this.onChanged,
  });
  final AlertModelType value;
  final ValueChanged<AlertModelType> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<AlertModelType>(
          value:           value,
          isExpanded:      true,
          underline:       const SizedBox.shrink(),
          dropdownColor:   ZapColors.bgCard,
          style:           ZapTypography.bodySmall,
          onChanged:       (v) { if (v != null) onChanged(v); },
          items: AlertModelType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Row(children: [
                  _ModelBadge(t.value),
                  const SizedBox(width: ZapSpacing.xs),
                  Text(t.label, style: ZapTypography.bodySmall),
                ]),
              )).toList(),
        ),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueStr,
    required this.valueColor,
    required this.child,
  });
  final String label;
  final String valueStr;
  final Color  valueColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FieldLabel(label),
              Text(valueStr,
                  style: ZapTypography.labelSmall
                      .copyWith(color: valueColor)),
            ],
          ),
          child,
        ],
      );
}

class _LatencyRow extends StatelessWidget {
  const _LatencyRow({
    required this.value,
    required this.onChanged,
  });
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const _FieldLabel('Max latency'),
          const Spacer(),
          Switch(
            value:      value != null,
            activeColor: ZapColors.info,
            onChanged:  (on) => onChanged(on ? 500.0 : null),
          ),
          if (value != null) ...[
            const SizedBox(width: ZapSpacing.xs),
            SizedBox(
              width: 100,
              child: Slider(
                value:      value!.clamp(50.0, 2000.0),
                min:        50.0,
                max:        2000.0,
                divisions:  39,
                activeColor: ZapColors.info,
                onChanged:  onChanged,
              ),
            ),
            Text(
              '${value!.toStringAsFixed(0)} ms',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.info),
            ),
          ] else
            Text('No limit',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary)),
        ],
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
          Row(
            children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: value - step >= min ? () => onChanged(value - step) : null,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                '$value',
                style: ZapTypography.labelMedium.copyWith(color: color),
              ),
              const SizedBox(width: ZapSpacing.sm),
              _StepBtn(
                icon: Icons.add,
                onTap: value + step <= max ? () => onChanged(value + step) : null,
              ),
            ],
          ),
        ],
      );
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData    icon;
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
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: ZapSpacing.xs),
          Text(label, style: ZapTypography.bodySmall),
          const Spacer(),
          Switch(
            value:      value,
            activeColor: color,
            onChanged:  onChanged,
          ),
        ],
      );
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge(this.modelType);
  final String modelType;

  @override
  Widget build(BuildContext context) {
    final color = _modelColor(modelType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        modelType.toUpperCase(),
        style: ZapTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.selected,
    required this.onSelect,
  });
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const opts = [('', 'All'), ('true', 'Active'), ('false', 'Inactive')];
    return Wrap(
      spacing: ZapSpacing.xs,
      children: opts.map((o) {
        final active = selected == o.$1;
        return GestureDetector(
          onTap: () => onSelect(o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: active ? ZapColors.warning : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? ZapColors.warning : ZapColors.bgElevated),
            ),
            child: Text(
              o.$2,
              style: ZapTypography.labelSmall.copyWith(
                color: active
                    ? ZapColors.bgPrimary
                    : ZapColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Color _confColor(double v) {
  if (v >= 0.8) return ZapColors.safe;
  if (v >= 0.5) return ZapColors.warning;
  return ZapColors.danger;
}

Color _modelColor(String type) {
  switch (type) {
    case 'scream': return ZapColors.danger;
    case 'motion': return ZapColors.warning;
    case 'scene':  return ZapColors.info;
    case 'dcs':    return ZapColors.safe;
    default:       return ZapColors.textSecondary;
  }
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
            style:
                ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
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
          const Icon(Icons.check_circle_rounded, size: 16, color: ZapColors.safe),
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
              color: ZapColors.warning, strokeWidth: 2),
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
