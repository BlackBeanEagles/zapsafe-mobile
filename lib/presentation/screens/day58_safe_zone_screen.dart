/// Day 58 — Safe Zone Screen
///
/// Route: /safe-zones
///
/// Full CRUD for circular GPS safe zones via:
///   POST   /api/v1/safe-zones/         create
///   GET    /api/v1/safe-zones/         list
///   PATCH  /api/v1/safe-zones/<pk>/    toggle active / edit
///   DELETE /api/v1/safe-zones/<pk>/    delete
///
/// Two sections:
///   ADD SAFE ZONE — inline form (name, lat/lng, radius, colour, notification
///                   preferences).
///   YOUR SAFE ZONES — live list from [safeZoneListProvider] with active/
///                     inactive filter, toggle-active chip, and delete button.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/safe_zone_service.dart';
import '../../domain/providers/safe_zone_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Preset colours the user can pick from
// ─────────────────────────────────────────────────────────────────────────────

const _kPresetColors = [
  '#06D6A0', // safe green
  '#4CC9F0', // info blue
  '#F4A261', // warning orange
  '#E63946', // danger red
  '#8F8FA3', // neutral grey
  '#A8DADC', // teal
];

const _kDefaultColor = '#06D6A0';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Day58SafeZoneScreen extends ConsumerStatefulWidget {
  const Day58SafeZoneScreen({super.key});

  @override
  ConsumerState<Day58SafeZoneScreen> createState() =>
      _Day58SafeZoneScreenState();
}

class _Day58SafeZoneScreenState extends ConsumerState<Day58SafeZoneScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _latCtrl   = TextEditingController();
  final _lngCtrl   = TextEditingController();
  final _radCtrl   = TextEditingController(text: '200');

  String _color         = _kDefaultColor;
  bool   _notifyEntry   = true;
  bool   _notifyExit    = true;

  // ── Submit state ──────────────────────────────────────────────────────────
  AsyncValue<SafeZone>? _createState;

  // ── List filter ───────────────────────────────────────────────────────────
  // null = all, true = active only, false = inactive only
  bool? _filterActive;

  // ── Per-zone mutation state  ───────────────────────────────────────────────
  // zone.id → 'toggling' | 'deleting'
  final Map<String, String> _zoneOp = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radCtrl.dispose();
    super.dispose();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final lat  = double.tryParse(_latCtrl.text.trim());
    final lng  = double.tryParse(_lngCtrl.text.trim());
    final rad  = int.tryParse(_radCtrl.text.trim());

    if (name.isEmpty || lat == null || lng == null || rad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all required fields.')),
      );
      return;
    }

    setState(() => _createState = const AsyncLoading());
    try {
      final svc  = ref.read(safeZoneServiceProvider);
      final zone = await svc.create(
        name:          name,
        latitude:      lat,
        longitude:     lng,
        radiusMeters:  rad,
        color:         _color,
        notifyOnEntry: _notifyEntry,
        notifyOnExit:  _notifyExit,
      );
      if (!mounted) return;
      setState(() => _createState = AsyncData(zone));
      ref.invalidate(safeZoneListProvider);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _createState = AsyncError(e, st));
    }
  }

  void _resetCreate() {
    setState(() {
      _createState = null;
      _nameCtrl.clear();
      _latCtrl.clear();
      _lngCtrl.clear();
      _radCtrl.text = '200';
      _color = _kDefaultColor;
      _notifyEntry = true;
      _notifyExit  = true;
    });
  }

  // ── Toggle active ──────────────────────────────────────────────────────────

  Future<void> _toggleActive(SafeZone zone) async {
    setState(() => _zoneOp[zone.id] = 'toggling');
    try {
      final svc = ref.read(safeZoneServiceProvider);
      await svc.patch(zone.id, {'is_active': !zone.isActive});
      ref.invalidate(safeZoneListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update zone.')),
        );
      }
    } finally {
      if (mounted) setState(() => _zoneOp.remove(zone.id));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete(SafeZone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZapColors.bgSurface,
        title: const Text('Delete Safe Zone',
            style: TextStyle(color: ZapColors.textPrimary)),
        content: Text(
          'Delete "${zone.name}"? This cannot be undone.',
          style: const TextStyle(color: ZapColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: ZapColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _zoneOp[zone.id] = 'deleting');
    try {
      await ref.read(safeZoneServiceProvider).delete(zone.id);
      ref.invalidate(safeZoneListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete zone.')),
        );
      }
    } finally {
      if (mounted) setState(() => _zoneOp.remove(zone.id));
    }
  }

  // ── Filter helper ──────────────────────────────────────────────────────────

  List<SafeZone> _applyFilter(List<SafeZone> all) {
    if (_filterActive == null) return all;
    return all.where((z) => z.isActive == _filterActive).toList();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(safeZoneListProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Safe Zones',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.safe.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('DAY 58',
                  style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.safe, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: ZapColors.textSecondary, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(safeZoneListProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Add zone form ──────────────────────────────────────────────
            const _SectionLabel('ADD SAFE ZONE'),
            const SizedBox(height: ZapSpacing.sm),
            _AddZoneForm(
              nameCtrl:     _nameCtrl,
              latCtrl:      _latCtrl,
              lngCtrl:      _lngCtrl,
              radCtrl:      _radCtrl,
              color:        _color,
              notifyEntry:  _notifyEntry,
              notifyExit:   _notifyExit,
              createState:  _createState,
              onColorPick:  (c) => setState(() => _color = c),
              onEntryToggle: (v) => setState(() => _notifyEntry = v),
              onExitToggle:  (v) => setState(() => _notifyExit = v),
              onCreate:     _create,
              onReset:      _resetCreate,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Zone list ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('YOUR SAFE ZONES'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: ZapColors.textSecondary, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.invalidate(safeZoneListProvider),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Filter chips
            _FilterBar(
              selected: _filterActive,
              onChanged: (v) => setState(() => _filterActive = v),
            ),
            const SizedBox(height: ZapSpacing.sm),

            // List
            listAsync.when(
              loading: () => const _SkeletonList(),
              error:   (e, _) => _ListError(
                message: e.toString(),
                onRetry: () => ref.invalidate(safeZoneListProvider),
              ),
              data: (list) {
                final zones = _applyFilter(list.zones);
                if (zones.isEmpty) {
                  return _EmptyList(
                      hasFilter: _filterActive != null,
                      total: list.count);
                }
                return Column(
                  children: [
                    _CountBadge(shown: zones.length, total: list.count),
                    const SizedBox(height: ZapSpacing.sm),
                    ...zones.map((z) => _ZoneCard(
                          zone:     z,
                          op:       _zoneOp[z.id],
                          onToggle: () => _toggleActive(z),
                          onDelete: () => _delete(z),
                        )),
                  ],
                );
              },
            ),

            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Zone Form
// ─────────────────────────────────────────────────────────────────────────────

class _AddZoneForm extends StatelessWidget {
  const _AddZoneForm({
    required this.nameCtrl,
    required this.latCtrl,
    required this.lngCtrl,
    required this.radCtrl,
    required this.color,
    required this.notifyEntry,
    required this.notifyExit,
    required this.createState,
    required this.onColorPick,
    required this.onEntryToggle,
    required this.onExitToggle,
    required this.onCreate,
    required this.onReset,
  });

  final TextEditingController nameCtrl, latCtrl, lngCtrl, radCtrl;
  final String color;
  final bool notifyEntry, notifyExit;
  final AsyncValue<SafeZone>? createState;
  final ValueChanged<String> onColorPick;
  final ValueChanged<bool>   onEntryToggle;
  final ValueChanged<bool>   onExitToggle;
  final VoidCallback onCreate, onReset;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name ───────────────────────────────────────────────────
            const _FieldLabel('ZONE NAME'),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              decoration: _inputDeco('e.g. Home, Work, Gym'),
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // ── Lat / Lng row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('LATITUDE'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: latCtrl,
                        decoration: _inputDeco('e.g. 28.6139'),
                        style: ZapTypography.bodyMedium
                            .copyWith(color: ZapColors.textPrimary),
                        keyboardType: const TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('LONGITUDE'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: lngCtrl,
                        decoration: _inputDeco('e.g. 77.2090'),
                        style: ZapTypography.bodyMedium
                            .copyWith(color: ZapColors.textPrimary),
                        keyboardType: const TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),

            // ── Radius ────────────────────────────────────────────────
            const _FieldLabel('RADIUS (METRES)  50 – 50 000'),
            const SizedBox(height: 6),
            TextField(
              controller: radCtrl,
              decoration: _inputDeco('e.g. 200'),
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: ZapSpacing.md),

            // ── Colour picker ─────────────────────────────────────────
            const _FieldLabel('ZONE COLOUR'),
            const SizedBox(height: ZapSpacing.sm),
            _ColorPicker(selected: color, onPick: onColorPick),
            const SizedBox(height: ZapSpacing.md),

            // ── Notification toggles ──────────────────────────────────
            _NotifToggle(
              icon:     Icons.login_rounded,
              label:    'Notify on entry',
              value:    notifyEntry,
              onChanged: onEntryToggle,
            ),
            const SizedBox(height: ZapSpacing.xs),
            _NotifToggle(
              icon:     Icons.logout_rounded,
              label:    'Notify on exit',
              value:    notifyExit,
              onChanged: onExitToggle,
            ),
            const SizedBox(height: ZapSpacing.lg),

            // ── Submit / result ───────────────────────────────────────
            _CreateResult(
              createState: createState,
              onCreate:    onCreate,
              onReset:     onReset,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary.withOpacity(0.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: ZapSpacing.md),
        filled: true,
        fillColor: ZapColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZapColors.safe, width: 1.5),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Color picker
// ─────────────────────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _kPresetColors.map((hex) {
        final isSelected = hex == selected;
        final color      = _hexColor(hex);
        return GestureDetector(
          onTap: () => onPick(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: ZapSpacing.sm),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? ZapColors.textPrimary
                    : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded,
                    size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification toggle row
// ─────────────────────────────────────────────────────────────────────────────

class _NotifToggle extends StatelessWidget {
  const _NotifToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String   label;
  final bool     value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: value
            ? ZapColors.safe.withOpacity(0.06)
            : ZapColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? ZapColors.safe.withOpacity(0.3)
              : ZapColors.border,
        ),
      ),
      child: SwitchListTile(
        dense:     true,
        value:     value,
        onChanged: onChanged,
        activeColor: ZapColors.safe,
        title: Text(label,
            style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textPrimary)),
        secondary: Icon(icon,
            size: 18,
            color: value ? ZapColors.safe : ZapColors.textSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create result area (idle / loading / success / error)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateResult extends StatelessWidget {
  const _CreateResult({
    required this.createState,
    required this.onCreate,
    required this.onReset,
  });

  final AsyncValue<SafeZone>? createState;
  final VoidCallback onCreate, onReset;

  @override
  Widget build(BuildContext context) {
    // ── Idle ────────────────────────────────────────────────────────────────
    if (createState == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_location_rounded),
          label: const Text('Add Safe Zone'),
          style: FilledButton.styleFrom(
            backgroundColor: ZapColors.safe,
            foregroundColor: ZapColors.textInverse,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: ZapTypography.bodyMedium
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    // ── Loading ──────────────────────────────────────────────────────────────
    if (createState!.isLoading) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ZapColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ZapColors.safe),
            ),
            SizedBox(width: ZapSpacing.sm),
            Text('Saving…',
                style: TextStyle(color: ZapColors.textSecondary)),
          ],
        ),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (createState!.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.danger.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ZapColors.danger.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ZapColors.danger, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(createState!.error.toString(),
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    // ── Success ──────────────────────────────────────────────────────────────
    final zone = createState!.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: ZapColors.safe, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('"${zone.name}" saved!',
                        style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.safe,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${zone.latitude.toStringAsFixed(4)}, '
                      '${zone.longitude.toStringAsFixed(4)}  '
                      '· r=${zone.radiusMeters} m',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add another'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ZapColors.safe,
              side: const BorderSide(color: ZapColors.safe),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});
  final bool? selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FChip(
          label: 'All',
          active: selected == null,
          color: ZapColors.info,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: ZapSpacing.sm),
        _FChip(
          label: 'Active',
          active: selected == true,
          color: ZapColors.safe,
          onTap: () => onChanged(selected == true ? null : true),
        ),
        const SizedBox(width: ZapSpacing.sm),
        _FChip(
          label: 'Disabled',
          active: selected == false,
          color: ZapColors.textSecondary,
          onTap: () => onChanged(selected == false ? null : false),
        ),
      ],
    );
  }
}

class _FChip extends StatelessWidget {
  const _FChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String     label;
  final bool       active;
  final Color      color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withOpacity(0.3),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Text(label,
            style: ZapTypography.labelSmall.copyWith(
              color: active ? color : ZapColors.textSecondary,
              fontWeight:
                  active ? FontWeight.w700 : FontWeight.normal,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zone card
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.op,
    required this.onToggle,
    required this.onDelete,
  });

  final SafeZone zone;
  final String?  op;       // 'toggling' | 'deleting' | null
  final VoidCallback onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    final zoneColor = _hexColor(zone.color);
    final fmt       = DateFormat('MMM d, y');
    final isBusy    = op != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: ZapCard(
        child: Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row ──────────────────────────────────────────────
              Row(
                children: [
                  // Colour dot
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: zoneColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),

                  // Name
                  Expanded(
                    child: Text(zone.name,
                        style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),

                  // Active badge
                  if (!isBusy)
                    _StatusBadge(isActive: zone.isActive),

                  // Busy spinner
                  if (isBusy)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ZapColors.safe),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Coords + radius ───────────────────────────────────────
              Text(
                '${zone.latitude.toStringAsFixed(5)}, '
                '${zone.longitude.toStringAsFixed(5)}'
                '  ·  r = ${zone.radiusMeters} m',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
              const SizedBox(height: ZapSpacing.xs),

              // ── Notification badges ───────────────────────────────────
              Row(
                children: [
                  _NotifBadge(
                      icon: Icons.login_rounded,
                      label: 'Entry',
                      on: zone.notifyOnEntry),
                  const SizedBox(width: ZapSpacing.sm),
                  _NotifBadge(
                      icon: Icons.logout_rounded,
                      label: 'Exit',
                      on: zone.notifyOnExit),
                  const Spacer(),
                  Text(fmt.format(zone.createdAt),
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              const Divider(color: ZapColors.border, height: 1),
              const SizedBox(height: ZapSpacing.sm),

              // ── Action buttons ────────────────────────────────────────
              Row(
                children: [
                  // Toggle active
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : onToggle,
                      icon: Icon(
                        zone.isActive
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        size: 18,
                        color: zone.isActive
                            ? ZapColors.safe
                            : ZapColors.textSecondary,
                      ),
                      label: Text(
                        zone.isActive ? 'Disable' : 'Enable',
                        style: ZapTypography.labelSmall.copyWith(
                          color: zone.isActive
                              ? ZapColors.safe
                              : ZapColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: zone.isActive
                              ? ZapColors.safe.withOpacity(0.4)
                              : ZapColors.border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),

                  // Delete
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: ZapColors.danger),
                    label: const Text('Delete',
                        style: TextStyle(color: ZapColors.danger)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: ZapColors.danger.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: ZapSpacing.sm, horizontal: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small badge widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? ZapColors.safe.withOpacity(0.12)
            : ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'OFF',
        style: ZapTypography.labelSmall.copyWith(
          color: isActive ? ZapColors.safe : ZapColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NotifBadge extends StatelessWidget {
  const _NotifBadge({
    required this.icon,
    required this.label,
    required this.on,
  });

  final IconData icon;
  final String   label;
  final bool     on;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12,
            color: on ? ZapColors.safe : ZapColors.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style: ZapTypography.labelSmall.copyWith(
              color: on ? ZapColors.safe : ZapColors.textSecondary,
              fontSize: 10,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600));
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: ZapTypography.labelSmall
            .copyWith(color: ZapColors.textSecondary, letterSpacing: 0.8));
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.shown, required this.total});
  final int shown, total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: ZapColors.info.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        shown == total
            ? '$total zone${total == 1 ? '' : 's'}'
            : 'Showing $shown of $total',
        style: ZapTypography.labelSmall
            .copyWith(color: ZapColors.info, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: ZapCard(
            child: Container(
              height: 90,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ZapColors.safe),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.hasFilter, required this.total});
  final bool hasFilter;
  final int  total;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          children: [
            Icon(
              hasFilter
                  ? Icons.filter_list_off_rounded
                  : Icons.location_off_rounded,
              size: 40,
              color: ZapColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              hasFilter
                  ? 'No zones match this filter'
                  : 'No safe zones yet',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textSecondary),
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              hasFilter
                  ? 'Try clearing the filter'
                  : 'Use the form above to add your first safe zone',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ZapColors.danger, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(message,
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility — parse #RRGGBB → Color
// ─────────────────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return ZapColors.safe;
  }
}
