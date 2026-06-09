/// Day 87 — SOS Message Templates editor (v2).
///
/// Create, edit, delete, and activate pre-composed emergency messages.
/// Supports {{location}}, {{time}}, and {{battery}} runtime placeholders.
/// Live preview card substitutes mock values to show how the SMS will look.
/// Placeholder toolbar inserts tags at the current cursor position.
///
/// API: PATCH /api/v1/sos-templates/<id>/ — Month 4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/sos_template_providers_v2.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _ago(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1)  { return 'just now'; }
  if (d.inMinutes < 60) { return '${d.inMinutes}m ago'; }
  if (d.inHours   < 24) { return '${d.inHours}h ago'; }
  return '${d.inDays}d ago';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day87SosTemplatesScreen extends ConsumerWidget {
  const Day87SosTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(sosTemplatesProvider);
    final defaultTemplate = templates.firstWhere(
      (t) => t.isDefault,
      orElse: () => templates.first,
    );

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: const Text(
          'SOS Templates',
          style: ZapTypography.headlineSmall,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: ZapColors.danger,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Template'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.lg, 100,
        ),
        children: [
          _ActiveBanner(template: defaultTemplate),
          const SizedBox(height: ZapSpacing.md),
          ...templates.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _TemplateCard(
                template:  t,
                canDelete: templates.length > 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context:             ctx,
      isScrollControlled:  true,
      backgroundColor:     ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateTemplateSheet(),
    );
  }
}

// ─── Active template banner ───────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.template});
  final SosTemplateV2 template;

  @override
  Widget build(BuildContext context) {
    final stats = template.sentCount > 0
        ? 'Sent ${template.sentCount}× · '
            'Last used ${_ago(template.lastUsed!)}'
        : 'Never sent';

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color:        ZapColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sos_rounded, color: ZapColors.danger, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Active: ${template.title}',
                  style: ZapTypography.labelMedium
                      .copyWith(color: ZapColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            template.resolvedPreview,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            stats,
            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Template card ────────────────────────────────────────────────────────────

class _TemplateCard extends ConsumerStatefulWidget {
  const _TemplateCard({required this.template, required this.canDelete});
  final SosTemplateV2 template;
  final bool          canDelete;

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  bool _expanded = false;
  bool _dirty    = false;

  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _notesCtrl;
  late bool _includeLocation;
  late bool _includeBattery;

  // Tracks last known valid cursor position in the body field.
  TextSelection _bodySelection = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    _load(widget.template);
    _titleCtrl = TextEditingController(text: widget.template.title);
    _bodyCtrl  = TextEditingController(text: widget.template.body);
    _notesCtrl = TextEditingController(text: widget.template.notes);
    _bodyCtrl.addListener(_trackBodyCursor);
  }

  @override
  void didUpdateWidget(_TemplateCard old) {
    super.didUpdateWidget(old);
    if (!_dirty) {
      _load(widget.template);
      _titleCtrl.text = widget.template.title;
      _bodyCtrl.text  = widget.template.body;
      _notesCtrl.text = widget.template.notes;
    }
  }

  @override
  void dispose() {
    _bodyCtrl.removeListener(_trackBodyCursor);
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _load(SosTemplateV2 t) {
    _includeLocation = t.includeLocation;
    _includeBattery  = t.includeBatteryLevel;
  }

  void _trackBodyCursor() {
    final sel = _bodyCtrl.selection;
    if (sel.isValid && sel.start >= 0) {
      _bodySelection = sel;
    }
  }

  void _markDirty() => setState(() { _dirty = true; });

  void _insertPlaceholder(String placeholder) {
    final sel   = _bodySelection;
    final body  = _bodyCtrl.text;
    final start = (sel.isValid && sel.start >= 0) ? sel.start : body.length;
    final end   = (sel.isValid && sel.end >= 0)   ? sel.end   : body.length;
    final newBody = body.replaceRange(start, end, placeholder);
    _bodyCtrl.value = TextEditingValue(
      text:      newBody,
      selection: TextSelection.collapsed(offset: start + placeholder.length),
    );
    _bodySelection = _bodyCtrl.selection;
    _markDirty();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) { return; }
    ref.read(sosTemplatesProvider.notifier).update(
      widget.template.copyWith(
        title:               title,
        body:                _bodyCtrl.text,
        includeLocation:     _includeLocation,
        includeBatteryLevel: _includeBattery,
        notes:               _notesCtrl.text.trim(),
      ),
    );
    setState(() { _dirty = false; _expanded = false; });
  }

  void _cancel() {
    _load(widget.template);
    _titleCtrl.text = widget.template.title;
    _bodyCtrl.text  = widget.template.body;
    _notesCtrl.text = widget.template.notes;
    setState(() { _dirty = false; _expanded = false; });
  }

  void _confirmDelete(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete template?', style: ZapTypography.headlineSmall),
        content: Text(
          'Delete "${widget.template.title}"? This cannot be undone.',
          style: ZapTypography.bodyMedium
              .copyWith(color: ZapColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              ref.read(sosTemplatesProvider.notifier).delete(widget.template.id);
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

  String get _resolvedPreview {
    var text = _bodyCtrl.text;
    kPreviewValues.forEach((key, val) {
      text = text.replaceAll(key, val);
    });
    return text;
  }

  int get _charCount => _resolvedPreview.length;
  int get _segments  => ((_charCount - 1) ~/ 160) + 1;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isDefault
              ? ZapColors.danger.withOpacity(0.45)
              : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
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
                      color: t.isDefault
                          ? ZapColors.danger.withOpacity(0.15)
                          : ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.message_rounded,
                      color: t.isDefault
                          ? ZapColors.danger
                          : ZapColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),

                  // Title + body preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.title,
                                style: ZapTypography.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (t.isDefault) ...[
                              const SizedBox(width: ZapSpacing.sm),
                              const _Chip(text: 'DEFAULT', color: ZapColors.danger),
                            ],
                            if (_dirty) ...[
                              const SizedBox(width: ZapSpacing.sm),
                              const _Chip(text: 'unsaved', color: ZapColors.warning),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.body,
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Char count chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:        ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${t.charCount}c',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textMuted, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),

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

          // ── Expanded body ────────────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(color: ZapColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live preview
                  _LivePreview(
                    resolvedText: _resolvedPreview,
                    charCount:    _charCount,
                    segments:     _segments,
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Title
                  const _Label('TITLE'),
                  const SizedBox(height: ZapSpacing.sm),
                  _Field(
                    controller: _titleCtrl,
                    hint:       'e.g. Standard SOS',
                    onChanged:  (_) => _markDirty(),
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Body + placeholder toolbar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(child: _Label('MESSAGE BODY')),
                      Text(
                        '$_charCount chars · $_segments SMS',
                        style: ZapTypography.bodySmall.copyWith(
                          color: _charCount > 320
                              ? ZapColors.warning
                              : ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  _Field(
                    controller: _bodyCtrl,
                    hint:       'Type your SOS message…',
                    maxLines:   5,
                    onChanged:  (_) => _markDirty(),
                  ),
                  const SizedBox(height: ZapSpacing.sm),

                  // Placeholder toolbar
                  _PlaceholderToolbar(onInsert: _insertPlaceholder),
                  const SizedBox(height: ZapSpacing.lg),

                  // Include location
                  _Toggle(
                    label:    'Include Location',
                    sublabel: 'Replaces {{location}} with GPS coordinates',
                    value:    _includeLocation,
                    onChanged: (v) {
                      setState(() { _includeLocation = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // Include battery
                  _Toggle(
                    label:    'Include Battery Level',
                    sublabel: 'Replaces {{battery}} with current charge %',
                    value:    _includeBattery,
                    onChanged: (v) {
                      setState(() { _includeBattery = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // Notes
                  const _Label('NOTES'),
                  const SizedBox(height: ZapSpacing.sm),
                  _Field(
                    controller: _notesCtrl,
                    hint:       'Optional description…',
                    maxLines:   2,
                    onChanged:  (_) => _markDirty(),
                  ),
                  const SizedBox(height: ZapSpacing.sm),

                  // Usage stats
                  if (t.sentCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                      child: Text(
                        'Sent ${t.sentCount}× · Last used ${_ago(t.lastUsed!)}',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textMuted),
                      ),
                    ),
                  const SizedBox(height: ZapSpacing.sm),

                  // Action row
                  Row(
                    children: [
                      if (!t.isDefault)
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(sosTemplatesProvider.notifier)
                              .setDefault(t.id),
                          icon:  const Icon(Icons.star_outline_rounded, size: 16),
                          label: const Text('Set Default'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZapColors.danger,
                            side: BorderSide(
                              color: ZapColors.danger.withOpacity(0.50),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md, vertical: ZapSpacing.xs,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      if (widget.canDelete) ...[
                        const SizedBox(width: ZapSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon:  const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ZapColors.textMuted,
                            side: const BorderSide(color: ZapColors.border),
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
                            backgroundColor: ZapColors.danger,
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

// ─── Live preview card ────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.resolvedText,
    required this.charCount,
    required this.segments,
  });

  final String resolvedText;
  final int    charCount;
  final int    segments;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        ZapColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: ZapSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.sms_rounded, size: 14, color: ZapColors.textMuted),
                const SizedBox(width: ZapSpacing.xs),
                Text(
                  'PREVIEW',
                  style: ZapTypography.labelSmall.copyWith(
                    color:         ZapColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  '$charCount chars · $segments SMS',
                  style: ZapTypography.bodySmall.copyWith(
                    color:    charCount > 320 ? ZapColors.warning : ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: ZapColors.divider, height: 1),

          // SMS bubble
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: ZapSpacing.sm,
                    ),
                    decoration: const BoxDecoration(
                      color:        ZapColors.bgElevated,
                      borderRadius: BorderRadius.only(
                        topLeft:     Radius.circular(12),
                        topRight:    Radius.circular(12),
                        bottomRight: Radius.circular(12),
                        bottomLeft:  Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      resolvedText.isEmpty ? '(empty message)' : resolvedText,
                      style: ZapTypography.bodySmall.copyWith(
                        color: resolvedText.isEmpty
                            ? ZapColors.textMuted
                            : ZapColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
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

// ─── Placeholder toolbar ──────────────────────────────────────────────────────

class _PlaceholderToolbar extends StatelessWidget {
  const _PlaceholderToolbar({required this.onInsert});
  final void Function(String) onInsert;

  static const _tags = [
    ('{{location}}', Icons.location_on_rounded,  '📍 Location'),
    ('{{time}}',     Icons.schedule_rounded,      '🕐 Time'),
    ('{{battery}}',  Icons.battery_4_bar_rounded, '🔋 Battery'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZapSpacing.sm,
      children: _tags.map((tag) {
        final (placeholder, icon, label) = tag;
        return OutlinedButton.icon(
          onPressed: () => onInsert(placeholder),
          icon:  Icon(icon, size: 14),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: ZapColors.info,
            side:            BorderSide(color: ZapColors.info.withOpacity(0.45)),
            padding:         const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: ZapSpacing.xs,
            ),
            textStyle: ZapTypography.bodySmall,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Create template sheet ────────────────────────────────────────────────────

class _CreateTemplateSheet extends ConsumerStatefulWidget {
  const _CreateTemplateSheet();

  @override
  ConsumerState<_CreateTemplateSheet> createState() =>
      _CreateTemplateSheetState();
}

class _CreateTemplateSheetState extends ConsumerState<_CreateTemplateSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController(
    text: 'HELP! I need assistance. My location: {{location}}. Time: {{time}}.',
  );
  final _notesCtrl = TextEditingController();

  bool    _includeLocation = true;
  bool    _includeBattery  = false;
  String? _titleError;

  TextSelection _bodySelection = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    _bodyCtrl.addListener(() {
      final sel = _bodyCtrl.selection;
      if (sel.isValid && sel.start >= 0) {
        _bodySelection = sel;
      }
    });
    _bodySelection = TextSelection.collapsed(offset: _bodyCtrl.text.length);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String placeholder) {
    final sel   = _bodySelection;
    final body  = _bodyCtrl.text;
    final start = (sel.isValid && sel.start >= 0) ? sel.start : body.length;
    final end   = (sel.isValid && sel.end >= 0)   ? sel.end   : body.length;
    final newBody = body.replaceRange(start, end, placeholder);
    _bodyCtrl.value = TextEditingValue(
      text:      newBody,
      selection: TextSelection.collapsed(offset: start + placeholder.length),
    );
    _bodySelection = _bodyCtrl.selection;
    setState(() {});
  }

  String get _resolvedPreview {
    var text = _bodyCtrl.text;
    kPreviewValues.forEach((key, val) {
      text = text.replaceAll(key, val);
    });
    return text;
  }

  int get _charCount => _resolvedPreview.length;
  int get _segments  => ((_charCount - 1) ~/ 160) + 1;

  void _create() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() { _titleError = 'Title is required'; });
      return;
    }
    final template = SosTemplateV2(
      id:                  't${DateTime.now().millisecondsSinceEpoch}',
      title:               title,
      body:                _bodyCtrl.text,
      includeLocation:     _includeLocation,
      includeBatteryLevel: _includeBattery,
      isDefault:           false,
      notes:               _notesCtrl.text.trim(),
      sentCount:           0,
      lastUsed:            null,
    );
    ref.read(sosTemplatesProvider.notifier).add(template);
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
            // Handle bar
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
            const Text('New SOS Template', style: ZapTypography.headlineSmall),
            const SizedBox(height: ZapSpacing.lg),

            // Live preview
            _LivePreview(
              resolvedText: _resolvedPreview,
              charCount:    _charCount,
              segments:     _segments,
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Title
            const _Label('TITLE *'),
            const SizedBox(height: ZapSpacing.sm),
            _Field(
              controller: _titleCtrl,
              hint:       'e.g. Night Mode',
              onChanged: (_) => setState(() { _titleError = null; }),
              errorText:  _titleError,
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Body
            Row(
              children: [
                const Expanded(child: _Label('MESSAGE BODY')),
                Text(
                  '$_charCount chars · $_segments SMS',
                  style: ZapTypography.bodySmall.copyWith(
                    color:    _charCount > 320 ? ZapColors.warning : ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            _Field(
              controller: _bodyCtrl,
              hint:       'Type your SOS message…',
              maxLines:   5,
              onChanged:  (_) => setState(() {}),
            ),
            const SizedBox(height: ZapSpacing.sm),
            _PlaceholderToolbar(onInsert: _insertPlaceholder),
            const SizedBox(height: ZapSpacing.lg),

            // Include toggles
            _Toggle(
              label:    'Include Location',
              sublabel: 'Replaces {{location}} with GPS coordinates',
              value:    _includeLocation,
              onChanged: (v) => setState(() { _includeLocation = v; }),
            ),
            const SizedBox(height: ZapSpacing.md),
            _Toggle(
              label:    'Include Battery Level',
              sublabel: 'Replaces {{battery}} with current charge %',
              value:    _includeBattery,
              onChanged: (v) => setState(() { _includeBattery = v; }),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Notes
            const _Label('NOTES'),
            const SizedBox(height: ZapSpacing.sm),
            _Field(
              controller: _notesCtrl,
              hint:       'Optional description…',
              maxLines:   2,
              onChanged:  (_) {},
            ),
            const SizedBox(height: ZapSpacing.xl),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZapColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Create Template'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.errorText,
  });

  final TextEditingController  controller;
  final String                 hint;
  final int                    maxLines;
  final void Function(String)? onChanged;
  final String?                errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style:      ZapTypography.bodyMedium,
      maxLines:   maxLines,
      onChanged:  onChanged,
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: ZapTypography.bodyMedium.copyWith(color: ZapColors.textMuted),
        errorText: errorText,
        filled:    true,
        fillColor: ZapColors.bgSurface,
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
          borderSide:   const BorderSide(color: ZapColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  final String              label;
  final String              sublabel;
  final bool                value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ZapTypography.labelMedium),
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
          activeColor: ZapColors.danger,
        ),
      ],
    );
  }
}
