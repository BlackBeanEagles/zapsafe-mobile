/// Day 66 — SOS Message Template Screen
///
/// Pre-composed emergency messages that the app sends to contacts when an
/// SOS is triggered.  Supports {{location}}, {{time}}, and {{battery}}
/// runtime placeholders.
///
/// • Create templates (POST /api/v1/sos-templates/)
/// • List templates — default shown with star badge at the top
/// • Edit (PATCH) each template inline
/// • Activate a template as default (POST /activate/)
/// • Delete a template (DELETE)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/sos_template_service.dart';
import '../../domain/providers/sos_template_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day66SosTemplateScreen extends ConsumerStatefulWidget {
  const Day66SosTemplateScreen({super.key});

  @override
  ConsumerState<Day66SosTemplateScreen> createState() =>
      _Day66SosTemplateScreenState();
}

class _Day66SosTemplateScreenState
    extends ConsumerState<Day66SosTemplateScreen> {
  // ── Create-form state ──────────────────────────────────────────────────────
  final _createTitleCtrl = TextEditingController();
  final _createBodyCtrl  = TextEditingController();
  final _createNotesCtrl = TextEditingController();
  bool  _createIncLoc     = true;
  bool  _createIncBat     = false;
  bool  _createIsDefault  = false;
  bool  _creating         = false;
  String? _createError;
  String? _createSuccessTitle;

  // ── Edit state (keyed by template id) ────────────────────────────────────
  String? _editingId;
  final   _editTitleCtrl = TextEditingController();
  final   _editBodyCtrl  = TextEditingController();
  final   _editNotesCtrl = TextEditingController();
  bool?   _editIncLoc;
  bool?   _editIncBat;
  bool    _saving     = false;
  String? _saveError;
  bool    _deleting   = false;
  bool    _activating = false;

  @override
  void dispose() {
    _createTitleCtrl.dispose();
    _createBodyCtrl.dispose();
    _createNotesCtrl.dispose();
    _editTitleCtrl.dispose();
    _editBodyCtrl.dispose();
    _editNotesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _startEditing(SosTemplate t) {
    if (_editingId == t.id) {
      setState(() => _editingId = null);
      return;
    }
    _editTitleCtrl.text = t.title;
    _editBodyCtrl.text  = t.body;
    _editNotesCtrl.text = t.notes;
    setState(() {
      _editingId  = t.id;
      _editIncLoc = t.includeLocation;
      _editIncBat = t.includeBatteryLevel;
      _saveError  = null;
    });
  }

  Future<void> _create() async {
    final title = _createTitleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _createError = 'Title is required.');
      return;
    }
    final body = _createBodyCtrl.text.trim();
    if (body.isEmpty) {
      setState(() => _createError = 'Message body is required.');
      return;
    }
    setState(() { _creating = true; _createError = null; _createSuccessTitle = null; });
    try {
      final created = await ref.read(sosTemplateServiceProvider).create(
            title:              title,
            body:               body,
            includeLocation:    _createIncLoc,
            includeBatteryLevel: _createIncBat,
            isDefault:          _createIsDefault,
            notes:              _createNotesCtrl.text.trim(),
          );
      ref.invalidate(sosTemplateListProvider);
      _createTitleCtrl.clear();
      _createBodyCtrl.clear();
      _createNotesCtrl.clear();
      setState(() {
        _createSuccessTitle = created.title;
        _createIncLoc       = true;
        _createIncBat       = false;
        _createIsDefault    = false;
      });
    } catch (e) {
      setState(() => _createError = e.toString());
    } finally {
      setState(() => _creating = false);
    }
  }

  Future<void> _save() async {
    if (_editingId == null) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      await ref.read(sosTemplateServiceProvider).update(
            _editingId!,
            title:              _editTitleCtrl.text.trim().isEmpty
                                    ? null
                                    : _editTitleCtrl.text.trim(),
            body:               _editBodyCtrl.text.trim().isEmpty
                                    ? null
                                    : _editBodyCtrl.text.trim(),
            includeLocation:    _editIncLoc,
            includeBatteryLevel: _editIncBat,
            notes:              _editNotesCtrl.text.trim(),
          );
      ref.invalidate(sosTemplateListProvider);
      setState(() => _editingId = null);
    } catch (e) {
      setState(() => _saveError = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _activate(String id) async {
    setState(() => _activating = true);
    try {
      await ref.read(sosTemplateServiceProvider).activate(id);
      ref.invalidate(sosTemplateListProvider);
    } catch (_) {}
    setState(() => _activating = false);
  }

  Future<void> _delete(String id) async {
    setState(() => _deleting = true);
    try {
      await ref.read(sosTemplateServiceProvider).delete(id);
      ref.invalidate(sosTemplateListProvider);
      setState(() { _editingId = null; _deleting = false; });
    } catch (e) {
      setState(() { _saveError = e.toString(); _deleting = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(sosTemplateListProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('SOS Templates',
            style: ZapTypography.headlineSmall),
        elevation: 0,
      ),
      body: listAsync.when(
        loading: () => const _Spinner(),
        error:   (e, _) => Center(child: _ErrorBanner(e.toString())),
        data: (templates) => ListView(
          padding: const EdgeInsets.all(ZapSpacing.md),
          children: [
            // ── Placeholder hint card ─────────────────────────────────────
            _PlaceholderHint(),
            const SizedBox(height: ZapSpacing.md),

            // ── Create card ───────────────────────────────────────────────
            _CreateCard(
              titleCtrl:    _createTitleCtrl,
              bodyCtrl:     _createBodyCtrl,
              notesCtrl:    _createNotesCtrl,
              incLoc:       _createIncLoc,
              incBat:       _createIncBat,
              isDefault:    _createIsDefault,
              creating:     _creating,
              onIncLoc:     (v) => setState(() => _createIncLoc = v),
              onIncBat:     (v) => setState(() => _createIncBat = v),
              onIsDefault:  (v) => setState(() => _createIsDefault = v),
              onCreate:     _create,
            ),
            if (_createError != null) ...[
              const SizedBox(height: ZapSpacing.xs),
              _ErrorBanner(_createError!),
            ],
            if (_createSuccessTitle != null) ...[
              const SizedBox(height: ZapSpacing.xs),
              _SuccessBanner('Created: "$_createSuccessTitle"'),
            ],
            const SizedBox(height: ZapSpacing.lg),

            // ── Template list ─────────────────────────────────────────────
            const _SectionLabel('YOUR TEMPLATES'),
            const SizedBox(height: ZapSpacing.md),

            if (templates.isEmpty)
              const _EmptyBox('No templates yet. Create one above.')
            else
              ...templates.map((t) => _TemplateCard(
                    template:     t,
                    isEditing:    _editingId == t.id,
                    editTitleCtrl: _editTitleCtrl,
                    editBodyCtrl:  _editBodyCtrl,
                    editNotesCtrl: _editNotesCtrl,
                    editIncLoc:    _editIncLoc,
                    editIncBat:    _editIncBat,
                    saving:       _saving,
                    deleting:     _deleting,
                    activating:   _activating,
                    saveError:    _editingId == t.id ? _saveError : null,
                    onTap:        () => _startEditing(t),
                    onIncLoc:     (v) => setState(() => _editIncLoc = v),
                    onIncBat:     (v) => setState(() => _editIncBat = v),
                    onSave:       _save,
                    onActivate:   () => _activate(t.id),
                    onDelete:     () => _delete(t.id),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder hint ─────────────────────────────────────────────────────────

class _PlaceholderHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.info.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.info.withOpacity(0.25)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: ZapColors.info),
              SizedBox(width: 4),
              Text('Runtime placeholders',
                  style: ZapTypography.labelSmall),
            ]),
            SizedBox(height: ZapSpacing.xs),
            Wrap(spacing: ZapSpacing.xs, runSpacing: 4, children: [
              _PlaceholderChip('{{location}}', 'GPS address'),
              _PlaceholderChip('{{time}}',     'event time'),
              _PlaceholderChip('{{battery}}',  'battery %'),
            ]),
          ],
        ),
      );
}

class _PlaceholderChip extends StatelessWidget {
  const _PlaceholderChip(this.tag, this.hint);
  final String tag;
  final String hint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(4),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: tag,
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.info),
              ),
              TextSpan(
                text: ' — $hint',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

// ─── Create card ──────────────────────────────────────────────────────────────

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.notesCtrl,
    required this.incLoc,
    required this.incBat,
    required this.isDefault,
    required this.creating,
    required this.onIncLoc,
    required this.onIncBat,
    required this.onIsDefault,
    required this.onCreate,
  });

  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController notesCtrl;
  final bool incLoc;
  final bool incBat;
  final bool isDefault;
  final bool creating;
  final ValueChanged<bool> onIncLoc;
  final ValueChanged<bool> onIncBat;
  final ValueChanged<bool> onIsDefault;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
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
              Icon(Icons.message_rounded, size: 18, color: ZapColors.danger),
              SizedBox(width: ZapSpacing.xs),
              Text('New SOS Template', style: ZapTypography.labelMedium),
            ]),
            const SizedBox(height: ZapSpacing.md),

            // Title
            const _FieldLabel('Template title *'),
            const SizedBox(height: ZapSpacing.xs),
            _TextField(
              controller: titleCtrl,
              hint: 'e.g. Being followed, Medical emergency',
              maxLength: 100,
            ),
            const SizedBox(height: ZapSpacing.md),

            // Body
            const _FieldLabel('Message body *'),
            const SizedBox(height: ZapSpacing.xs),
            _TextField(
              controller: bodyCtrl,
              hint:
                  'e.g. HELP! I\'m in danger at {{location}}. Call police now!',
              maxLines:  4,
              maxLength: 500,
            ),
            const SizedBox(height: ZapSpacing.md),

            // Append flags
            const _SectionLabel('APPEND TO MESSAGE'),
            const SizedBox(height: ZapSpacing.xs),
            _ToggleRow(
              icon:      Icons.location_on_rounded,
              color:     ZapColors.safe,
              label:     'Include live location',
              value:     incLoc,
              onChanged: onIncLoc,
            ),
            _ToggleRow(
              icon:      Icons.battery_4_bar_rounded,
              color:     ZapColors.info,
              label:     'Include battery level',
              value:     incBat,
              onChanged: onIncBat,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Set as default
            _ToggleRow(
              icon:      Icons.star_rounded,
              color:     ZapColors.warning,
              label:     'Set as default on create',
              value:     isDefault,
              onChanged: onIsDefault,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Notes
            const _FieldLabel('Notes (optional)'),
            const SizedBox(height: ZapSpacing.xs),
            _TextField(
              controller: notesCtrl,
              hint: 'e.g. use during late-night commute',
            ),
            const SizedBox(height: ZapSpacing.md),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: creating ? null : onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZapColors.danger,
                  foregroundColor: ZapColors.bgPrimary,
                  padding:
                      const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: creating
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ZapColors.bgPrimary))
                    : const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  creating ? 'Creating…' : 'Create Template',
                  style: ZapTypography.labelMedium
                      .copyWith(color: ZapColors.bgPrimary),
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Template card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isEditing,
    required this.editTitleCtrl,
    required this.editBodyCtrl,
    required this.editNotesCtrl,
    required this.editIncLoc,
    required this.editIncBat,
    required this.saving,
    required this.deleting,
    required this.activating,
    required this.saveError,
    required this.onTap,
    required this.onIncLoc,
    required this.onIncBat,
    required this.onSave,
    required this.onActivate,
    required this.onDelete,
  });

  final SosTemplate template;
  final bool  isEditing;
  final TextEditingController editTitleCtrl;
  final TextEditingController editBodyCtrl;
  final TextEditingController editNotesCtrl;
  final bool?  editIncLoc;
  final bool?  editIncBat;
  final bool   saving;
  final bool   deleting;
  final bool   activating;
  final String? saveError;
  final VoidCallback onTap;
  final ValueChanged<bool> onIncLoc;
  final ValueChanged<bool> onIncBat;
  final VoidCallback onSave;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = template;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEditing
                ? ZapColors.danger
                : t.isDefault
                    ? ZapColors.warning.withOpacity(0.5)
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(t.title,
                              style: ZapTypography.labelMedium),
                          if (t.isDefault) ...[
                            const SizedBox(width: ZapSpacing.xs),
                            _DefaultBadge(),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          t.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        // Append flags row
                        Wrap(spacing: 4, children: [
                          if (t.includeLocation)
                            const _FlagChip(
                                Icons.location_on_rounded,
                                'location',
                                ZapColors.safe),
                          if (t.includeBatteryLevel)
                            const _FlagChip(
                                Icons.battery_4_bar_rounded,
                                'battery',
                                ZapColors.info),
                          if (t.body.contains('{{'))
                            const _FlagChip(
                                Icons.data_object_rounded,
                                'placeholders',
                                ZapColors.warning),
                        ]),
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
                    // Title
                    const _FieldLabel('Title'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TextField(
                      controller: editTitleCtrl,
                      hint: 'Template title',
                      maxLength: 100,
                    ),
                    const SizedBox(height: ZapSpacing.md),

                    // Body
                    const _FieldLabel('Message body'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TextField(
                      controller: editBodyCtrl,
                      hint: 'Emergency message…',
                      maxLines:  4,
                      maxLength: 500,
                    ),
                    const SizedBox(height: ZapSpacing.md),

                    // Flags
                    _ToggleRow(
                      icon:      Icons.location_on_rounded,
                      color:     ZapColors.safe,
                      label:     'Include live location',
                      value:     editIncLoc ?? t.includeLocation,
                      onChanged: onIncLoc,
                    ),
                    _ToggleRow(
                      icon:      Icons.battery_4_bar_rounded,
                      color:     ZapColors.info,
                      label:     'Include battery level',
                      value:     editIncBat ?? t.includeBatteryLevel,
                      onChanged: onIncBat,
                    ),
                    const SizedBox(height: ZapSpacing.sm),

                    // Notes
                    const _FieldLabel('Notes'),
                    const SizedBox(height: ZapSpacing.xs),
                    _TextField(
                      controller: editNotesCtrl,
                      hint: 'Optional memo',
                    ),

                    if (saveError != null) ...[
                      const SizedBox(height: ZapSpacing.xs),
                      _ErrorBanner(saveError!),
                    ],
                    const SizedBox(height: ZapSpacing.sm),

                    // Action buttons
                    Row(children: [
                      // Set Default (only shown if not already default)
                      if (!t.isDefault)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: activating ? null : onActivate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZapColors.warning,
                              foregroundColor: ZapColors.bgPrimary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            icon: activating
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ZapColors.bgPrimary))
                                : const Icon(Icons.star_rounded,
                                    size: 15),
                            label: Text(
                              activating ? '…' : 'Set Default',
                              style: ZapTypography.labelSmall
                                  .copyWith(
                                      color: ZapColors.bgPrimary),
                            ),
                          ),
                        ),
                      if (!t.isDefault)
                        const SizedBox(width: ZapSpacing.xs),

                      // Save
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZapColors.info,
                            foregroundColor: ZapColors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                          ),
                          icon: saving
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ZapColors.textPrimary))
                              : const Icon(Icons.save_rounded,
                                  size: 15),
                          label: Text(
                            saving ? 'Saving…' : 'Save',
                            style: ZapTypography.labelSmall,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.xs),

                      // Delete
                      OutlinedButton.icon(
                        onPressed: deleting ? null : onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZapColors.danger,
                          side: const BorderSide(
                              color: ZapColors.danger),
                          padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md,
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                        icon: deleting
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ZapColors.danger))
                            : const Icon(
                                Icons.delete_outline_rounded,
                                size: 15),
                        label: Text(
                          deleting ? '…' : 'Delete',
                          style: ZapTypography.labelSmall,
                        ),
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
          color: ZapColors.warning.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(children: [
          Icon(Icons.star_rounded, size: 10, color: ZapColors.warning),
          SizedBox(width: 2),
          Text('DEFAULT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ZapColors.warning,
              )),
        ]),
      );
}

class _FlagChip extends StatelessWidget {
  const _FlagChip(this.icon, this.label, this.color);
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(label,
              style: ZapTypography.labelSmall.copyWith(color: color)),
        ]),
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
  const _TextField({
    required this.controller,
    this.hint      = '',
    this.maxLines  = 1,
    this.maxLength,
  });
  final TextEditingController controller;
  final String hint;
  final int    maxLines;
  final int?   maxLength;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines:   maxLines,
        maxLength:  maxLength,
        style:      ZapTypography.bodySmall,
        decoration: InputDecoration(
          filled:       true,
          fillColor:    ZapColors.bgElevated,
          hintText:     hint,
          hintStyle:    ZapTypography.bodySmall
              .copyWith(color: ZapColors.textSecondary),
          counterStyle: ZapTypography.labelSmall
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
          border:
              Border.all(color: ZapColors.danger.withOpacity(0.4)),
        ),
        child: Text(message,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.danger)),
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
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.safe)),
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
              color: ZapColors.danger, strokeWidth: 2),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
          child: Text(message,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary)),
        ),
      );
}
