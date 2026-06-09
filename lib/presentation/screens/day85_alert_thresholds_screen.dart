/// Day 85 — Alert Thresholds editor (v2).
///
/// 4 model cards (scream / motion / scene / DCS fusion) each expandable.
/// Features per card: confidence slider, consecutive-trigger stepper,
/// cooldown dropdown, auto-SOS + notify-contacts toggles, notes field,
/// "Test Fire" mock animation, "Apply Preset" reset to recommended values.
/// Conflict banner when >1 active rule has auto-SOS enabled.
///
/// API: PATCH /api/v1/alert-thresholds/<id>/ — Month 4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/threshold_providers_v2.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _ago(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1)  { return 'just now'; }
  if (d.inMinutes < 60) { return '${d.inMinutes}m ago'; }
  if (d.inHours   < 24) { return '${d.inHours}h ago'; }
  return '${d.inDays}d ago';
}

Color _confidenceColor(double c) {
  if (c >= 0.80) { return ZapColors.safe; }
  if (c >= 0.65) { return ZapColors.warning; }
  return ZapColors.danger;
}

String _cooldownLabel(int s) {
  if (s < 60) { return '${s}s'; }
  final m = s ~/ 60;
  final r = s % 60;
  return r == 0 ? '${m}m' : '${m}m ${r}s';
}

const _cooldownOptions = [15, 30, 45, 60, 90, 120, 180, 300];

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day85AlertThresholdsScreen extends ConsumerWidget {
  const Day85AlertThresholdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules        = ref.watch(thresholdsProvider);
    final activeCount  = rules.where((r) => r.isActive).length;
    final autoSosCount = rules.where((r) => r.isActive && r.autoSos).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: const Text('Alert Thresholds', style: ZapTypography.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            color: ZapColors.textSecondary,
            tooltip: 'Reset all to defaults',
            onPressed: () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          _SummaryRow(activeCount: activeCount, total: rules.length, rules: rules),
          const SizedBox(height: ZapSpacing.md),
          if (autoSosCount > 1) ...[
            _ConflictBanner(count: autoSosCount),
            const SizedBox(height: ZapSpacing.md),
          ],
          ...rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _ModelCard(rule: r),
            ),
          ),
          const SizedBox(height: ZapSpacing.xxxl),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext ctx, WidgetRef ref) {
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset all to defaults?', style: ZapTypography.headlineSmall),
        content: Text(
          'All 4 thresholds will be restored to recommended values.',
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
              ref.read(thresholdsProvider.notifier).resetAll();
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('All thresholds reset to defaults')),
              );
            },
            child: Text(
              'Reset',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.activeCount,
    required this.total,
    required this.rules,
  });

  final int                   activeCount;
  final int                   total;
  final List<ThresholdRuleV2> rules;

  @override
  Widget build(BuildContext context) {
    DateTime? lastTrigger;
    for (final r in rules) {
      if (r.lastTriggered != null) {
        if (lastTrigger == null || r.lastTriggered!.isAfter(lastTrigger)) {
          lastTrigger = r.lastTriggered;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical:   ZapSpacing.md,
      ),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          _Stat(
            value: '$activeCount / $total',
            label: 'Active rules',
            color: activeCount > 0 ? ZapColors.safe : ZapColors.textMuted,
          ),
          Container(
            width: 1, height: 32,
            margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
            color: ZapColors.divider,
          ),
          _Stat(
            value: lastTrigger == null ? 'Never' : _ago(lastTrigger),
            label: 'Last trigger',
            color: ZapColors.textSecondary,
          ),
          const Spacer(),
          const Icon(Icons.shield_outlined, color: ZapColors.safe, size: 20),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: ZapTypography.labelLarge.copyWith(color: color)),
        Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted)),
      ],
    );
  }
}

// ─── Conflict banner ─────────────────────────────────────────────────────────

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: ZapColors.danger.withOpacity(0.40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: ZapColors.danger, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              '$count rules have Auto-SOS enabled — '
              'the highest-confidence rule fires first.',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Model card ──────────────────────────────────────────────────────────────

class _ModelCard extends ConsumerStatefulWidget {
  const _ModelCard({required this.rule});
  final ThresholdRuleV2 rule;

  @override
  ConsumerState<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends ConsumerState<_ModelCard> {
  bool _expanded    = false;
  bool _dirty       = false;
  bool _testLoading = false;

  late double _confidence;
  late int    _consecutive;
  late int    _cooldown;
  late bool   _autoSos;
  late bool   _notifyContacts;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _loadFromRule(widget.rule);
    _notesCtrl = TextEditingController(text: widget.rule.notes);
  }

  @override
  void didUpdateWidget(_ModelCard old) {
    super.didUpdateWidget(old);
    if (!_dirty) {
      _loadFromRule(widget.rule);
      _notesCtrl.text = widget.rule.notes;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _loadFromRule(ThresholdRuleV2 r) {
    _confidence    = r.confidence;
    _consecutive   = r.consecutiveTriggers;
    _cooldown      = r.cooldownSeconds;
    _autoSos       = r.autoSos;
    _notifyContacts = r.notifyContacts;
  }

  void _markDirty() => setState(() { _dirty = true; });

  void _save() {
    ref.read(thresholdsProvider.notifier).update(
      widget.rule.model,
      widget.rule.copyWith(
        confidence:          _confidence,
        consecutiveTriggers: _consecutive,
        cooldownSeconds:     _cooldown,
        autoSos:             _autoSos,
        notifyContacts:      _notifyContacts,
        notes:               _notesCtrl.text.trim(),
      ),
    );
    setState(() { _dirty = false; _expanded = false; });
  }

  void _cancel() {
    _loadFromRule(widget.rule);
    _notesCtrl.text = widget.rule.notes;
    setState(() { _dirty = false; _expanded = false; });
  }

  void _applyPreset() {
    final m = widget.rule.model;
    setState(() {
      _confidence  = m.recommendedConfidence;
      _consecutive = m.recommendedConsecutive;
      _cooldown    = m.recommendedCooldown;
      _dirty       = true;
    });
  }

  Future<void> _testFire() async {
    setState(() { _testLoading = true; });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) { return; }
    ref.read(thresholdsProvider.notifier).mockTestFire(widget.rule.model);
    setState(() { _testLoading = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test trigger sent — ${widget.rule.model.label}'),
        backgroundColor: widget.rule.model.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r      = widget.rule;
    final accent = r.model.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r.isActive ? accent.withOpacity(0.40) : ZapColors.border,
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
                  // Model icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: r.isActive
                          ? accent.withOpacity(0.15)
                          : ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      r.model.icon,
                      color: r.isActive ? accent : ZapColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),

                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(r.model.label, style: ZapTypography.labelLarge),
                            if (_dirty) ...[
                              const SizedBox(width: ZapSpacing.sm),
                              const _Badge(
                                text:  'unsaved',
                                color: ZapColors.warning,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _confidenceColor(r.confidence),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(r.confidence * 100).round()}% confidence',
                              style: ZapTypography.bodySmall
                                  .copyWith(color: ZapColors.textMuted),
                            ),
                            if (r.lastTriggered != null) ...[
                              const SizedBox(width: ZapSpacing.sm),
                              Text(
                                '· ${_ago(r.lastTriggered!)}',
                                style: ZapTypography.bodySmall
                                    .copyWith(color: ZapColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Active switch
                  Switch(
                    value:      r.isActive,
                    onChanged:  (_) => ref
                        .read(thresholdsProvider.notifier)
                        .toggleActive(r.model),
                    activeColor: accent,
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

          // ── Expanded body ────────────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(color: ZapColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    r.model.description,
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // ── Confidence slider ─────────────────────────────────────
                  const _FieldLabel('CONFIDENCE THRESHOLD'),
                  const SizedBox(height: ZapSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor:   _confidenceColor(_confidence),
                            thumbColor:         _confidenceColor(_confidence),
                            inactiveTrackColor: ZapColors.border,
                            overlayColor:
                                _confidenceColor(_confidence).withOpacity(0.15),
                          ),
                          child: Slider(
                            value:    _confidence,
                            min:      0.40,
                            max:      1.00,
                            divisions: 12,
                            onChanged: (v) {
                              setState(() {
                                _confidence = (v * 100).round() / 100;
                              });
                              _markDirty();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.sm,
                          vertical:   ZapSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _confidenceColor(_confidence).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${(_confidence * 100).round()}%',
                          style: ZapTypography.labelMedium.copyWith(
                            color: _confidenceColor(_confidence),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'More sensitive',
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textMuted, fontSize: 10,
                          ),
                        ),
                        Text(
                          'Fewer false alarms',
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textMuted, fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // ── Consecutive triggers ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(child: _FieldLabel('CONSECUTIVE TRIGGERS')),
                      _Stepper(
                        value:    _consecutive,
                        min:      1,
                        max:      5,
                        onChanged: (v) {
                          setState(() { _consecutive = v; });
                          _markDirty();
                        },
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: ZapSpacing.xs, bottom: ZapSpacing.lg),
                    child: Text(
                      'Detections required before the alert fires',
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textMuted,
                      ),
                    ),
                  ),

                  // ── Cooldown ──────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(child: _FieldLabel('COOLDOWN')),
                      DropdownButton<int>(
                        value:          _cooldown,
                        dropdownColor:  ZapColors.bgCard,
                        style: ZapTypography.bodyMedium.copyWith(
                          color: ZapColors.textPrimary,
                        ),
                        underline: const SizedBox.shrink(),
                        items: _cooldownOptions
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s,
                                child: Text(_cooldownLabel(s)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() { _cooldown = v; });
                            _markDirty();
                          }
                        },
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: ZapSpacing.xs, bottom: ZapSpacing.lg),
                    child: Text(
                      'Minimum time between consecutive alerts',
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
                    ),
                  ),

                  // ── Auto-SOS ──────────────────────────────────────────────
                  _BoolRow(
                    label:    'Auto-SOS',
                    sublabel: 'Immediately trigger SOS on detection',
                    value:    _autoSos,
                    accent:   _autoSos ? ZapColors.danger : null,
                    onChanged: (v) {
                      setState(() { _autoSos = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // ── Notify contacts ───────────────────────────────────────
                  _BoolRow(
                    label:    'Notify Contacts',
                    sublabel: 'Send alert to emergency contacts tier 1 & 2',
                    value:    _notifyContacts,
                    onChanged: (v) {
                      setState(() { _notifyContacts = v; });
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: ZapSpacing.lg),

                  // ── Notes ─────────────────────────────────────────────────
                  const _FieldLabel('NOTES'),
                  const SizedBox(height: ZapSpacing.sm),
                  TextField(
                    controller: _notesCtrl,
                    style:      ZapTypography.bodyMedium,
                    maxLines:   2,
                    onChanged:  (_) => _markDirty(),
                    decoration: InputDecoration(
                      hintText: 'Optional note about this rule…',
                      hintStyle: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textMuted,
                      ),
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
                        borderSide:   BorderSide(color: accent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md,
                        vertical:   ZapSpacing.sm,
                      ),
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.md),

                  // ── Last triggered ────────────────────────────────────────
                  if (r.lastTriggered != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                      child: Text(
                        'Last triggered: ${_ago(r.lastTriggered!)}',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textMuted),
                      ),
                    ),

                  // ── Action row ────────────────────────────────────────────
                  Row(
                    children: [
                      // Test fire
                      if (_testLoading)
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: r.isActive ? _testFire : null,
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('Test'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accent,
                            side: BorderSide(color: accent.withOpacity(0.50)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md, vertical: ZapSpacing.xs,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      const SizedBox(width: ZapSpacing.sm),

                      // Apply preset
                      OutlinedButton.icon(
                        onPressed: _applyPreset,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                        label: const Text('Preset'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ZapColors.textSecondary,
                          side: const BorderSide(color: ZapColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.md, vertical: ZapSpacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
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
                            backgroundColor: accent,
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

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
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
        style: ZapTypography.bodySmall
            .copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

// ─── Field label ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ZapTypography.labelSmall.copyWith(
        color:         ZapColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ─── Bool row ─────────────────────────────────────────────────────────────────

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

// ─── Int stepper ─────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int              value;
  final int              min;
  final int              max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon:      Icons.remove_rounded,
          enabled:   value > min,
          onPressed: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            style:      ZapTypography.labelLarge,
            textAlign:  TextAlign.center,
          ),
        ),
        _StepBtn(
          icon:      Icons.add_rounded,
          enabled:   value < max,
          onPressed: () => onChanged(value + 1),
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
          color: enabled ? ZapColors.bgSurface : ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ZapColors.border),
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
