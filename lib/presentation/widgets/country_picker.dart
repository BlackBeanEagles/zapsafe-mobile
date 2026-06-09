import 'package:flutter/material.dart';

import '../../core/constants/countries.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/country.dart';

/// Bottom-sheet picker for [Country].
///
/// Usage:
/// ```dart
/// final picked = await CountryPicker.show(context, selected: currentCountry);
/// if (picked != null) setState(() => country = picked);
/// ```
///
/// The sheet handles its own search state, fills 80 % of screen height, and
/// always pins the currently-selected country at the top of the list when
/// there's no active search query.
class CountryPicker {
  CountryPicker._();

  static Future<Country?> show(
    BuildContext context, {
    Country? selected,
  }) {
    return showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _CountryPickerSheet(selected: selected),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final Country? selected;
  const _CountryPickerSheet({this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Country> _filtered() {
    final q = _q.trim().toLowerCase();
    final base = q.isEmpty
        ? _withSelectedFirst(Countries.all, widget.selected)
        : Countries.all.where((c) {
            return c.name.toLowerCase().contains(q) ||
                (c.nativeName?.toLowerCase().contains(q) ?? false) ||
                c.dialCode.contains(q) ||
                c.iso.toLowerCase().contains(q);
          }).toList();
    return base;
  }

  List<Country> _withSelectedFirst(List<Country> all, Country? sel) {
    if (sel == null) return all;
    return [
      sel,
      ...all.where((c) => c.iso != sel.iso),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final list = _filtered();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: Container(
            decoration: const BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusLarge),
              ),
              border: Border(
                top: BorderSide(color: ZapColors.border, width: 1),
                left: BorderSide(color: ZapColors.border, width: 1),
                right: BorderSide(color: ZapColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: ZapSpacing.md),
                _grabber(),
                const SizedBox(height: ZapSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
                  child: Row(
                    children: [
                      Text(
                        'Select country',
                        style: ZapTypography.headlineMedium.copyWith(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, color: ZapColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                _searchField(),
                const SizedBox(height: ZapSpacing.md),
                Expanded(
                  child: list.isEmpty ? _emptyState() : _listView(list, scrollController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Subwidgets ────────────────────────────────────────────────────────

  Widget _grabber() {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: ZapColors.border,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border, width: 1),
        ),
        child: TextField(
          controller: _searchCtrl,
          autofocus: false,
          onChanged: (v) => setState(() => _q = v),
          style: ZapTypography.bodyLarge.copyWith(color: ZapColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: ZapColors.textSecondary,
              size: 20,
            ),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: ZapColors.textSecondary, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                    },
                  ),
            hintText: 'Country or dial code (e.g. "India" or "+91")',
            hintStyle: ZapTypography.bodyMedium.copyWith(color: ZapColors.textMuted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md,
              vertical: ZapSpacing.md,
            ),
          ),
        ),
      ),
    );
  }

  Widget _listView(List<Country> list, ScrollController controller) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(ZapSpacing.sm, 0, ZapSpacing.sm, ZapSpacing.huge),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c = list[i];
        final isSelected = widget.selected?.iso == c.iso;
        return _CountryRow(
          country: c,
          selected: isSelected,
          onTap: () => Navigator.of(context).pop(c),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: ZapColors.textSecondary, size: 40),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'No matches',
              style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              'Tip: try the dial code (e.g. "+1" for US/Canada).',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final Country country;
  final bool selected;
  final VoidCallback onTap;

  const _CountryRow({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md,
            vertical: ZapSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            color: selected ? ZapColors.danger.withOpacity(0.06) : Colors.transparent,
          ),
          constraints: const BoxConstraints(minHeight: ZapSpacing.minTouchTarget),
          child: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      style: ZapTypography.bodyLarge.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (country.nativeName != null)
                      Text(
                        country.nativeName!,
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? ZapColors.danger : ZapColors.bgSurface,
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
                  border: Border.all(
                    color: selected ? ZapColors.danger : ZapColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  '+${country.dialCode}',
                  style: ZapTypography.monoSmall.copyWith(
                    color: selected ? Colors.white : ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: ZapSpacing.sm),
                const Icon(Icons.check_circle_rounded, color: ZapColors.danger, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
