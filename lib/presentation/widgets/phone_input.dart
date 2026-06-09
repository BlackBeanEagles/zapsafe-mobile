import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/country.dart';
import 'country_picker.dart';

/// A single phone-number field that's split into a tappable country chip
/// (flag + dial code) on the left and a digits-only text field on the right.
///
/// The widget owns the live grouping formatter (e.g. `98765 43210`) and the
/// country chip's tap-to-pick handler. The parent owns the [country] /
/// [digits] values via the standard controlled-input pattern.
///
/// Usage:
/// ```dart
/// PhoneInput(
///   country: country,
///   onCountryChanged: (c) => setState(() => country = c),
///   controller: digitsCtrl,
///   errorText: error,
///   onChanged: validate,
/// )
/// ```
class PhoneInput extends StatefulWidget {
  final Country country;
  final ValueChanged<Country> onCountryChanged;

  /// External controller — the raw digits (no spaces, no `+`, no dial code).
  final TextEditingController controller;

  /// Inline error shown below the field. Null = no error.
  final String? errorText;

  /// Fires on every keystroke with the cleaned digits string.
  final ValueChanged<String>? onChanged;

  /// Fires when the user submits via the keyboard action button.
  final ValueChanged<String>? onSubmitted;

  /// Disables the entire field (chip + input).
  final bool enabled;

  /// Auto-focus the phone digit field on mount.
  final bool autofocus;

  const PhoneInput({
    super.key,
    required this.country,
    required this.onCountryChanged,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocus);
  }

  void _onFocus() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await CountryPicker.show(context, selected: widget.country);
    if (picked != null && picked.iso != widget.country.iso) {
      widget.onCountryChanged(picked);
      // Reset digits — different countries have different formats; carrying
      // 10 IN digits into a US slot just makes both halves wrong.
      widget.controller.clear();
      widget.onChanged?.call('');
    }
  }

  Color _borderColor() {
    if (widget.errorText != null) return ZapColors.error;
    if (_focused) return ZapColors.info;
    return ZapColors.border;
  }

  double _borderWidth() => (_focused || widget.errorText != null) ? 2.0 : 1.0;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: _borderColor(), width: _borderWidth()),
          ),
          child: Row(
            children: [
              _CountryChip(
                country: widget.country,
                onTap: widget.enabled ? _pickCountry : null,
                hasError: hasError,
              ),
              Container(
                width: 1,
                height: 36,
                color: ZapColors.border,
              ),
              Expanded(
                child: Semantics(
                  label: 'Phone number input for ${widget.country.name}',
                  textField: true,
                  enabled: widget.enabled,
                  child: TextField(
                    focusNode: _focus,
                    controller: widget.controller,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.country.maxLength),
                      _GroupingFormatter(widget.country),
                    ],
                    cursorColor: ZapColors.info,
                    style: ZapTypography.bodyLarge.copyWith(
                      color: ZapColors.textPrimary,
                      fontFamily: 'IBMPlexMono',
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: _hintForCountry(widget.country),
                      hintStyle: ZapTypography.bodyLarge.copyWith(
                        color: ZapColors.textMuted,
                        fontFamily: 'IBMPlexMono',
                        letterSpacing: 0.5,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md,
                        vertical: ZapSpacing.lg,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (formatted) {
                      // Strip the grouping spaces before notifying the parent.
                      final cleaned = formatted.replaceAll(' ', '');
                      widget.onChanged?.call(cleaned);
                    },
                    onSubmitted: (formatted) {
                      widget.onSubmitted?.call(formatted.replaceAll(' ', ''));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Semantics(
            label: 'Error: ${widget.errorText}',
            child: Padding(
              padding: const EdgeInsets.only(top: ZapSpacing.sm, left: ZapSpacing.xs),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: ZapColors.error, size: 14),
                  const SizedBox(width: ZapSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.errorText!,
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Country-specific placeholder formatted with the country's grouping.
  String _hintForCountry(Country c) {
    switch (c.iso) {
      case 'IN':
        return '98765 43210';
      case 'US':
      case 'CA':
        return '415 555 0132';
      case 'GB':
        return '7700 900123';
      case 'AE':
        return '50 123 4567';
      default:
        // Generic: groups of three digits.
        final len = c.maxLength;
        return List.generate(len, (_) => '0').join();
    }
  }
}

// ─── Country chip (the left half) ─────────────────────────────────────────

class _CountryChip extends StatelessWidget {
  final Country country;
  final VoidCallback? onTap;
  final bool hasError;

  const _CountryChip({
    required this.country,
    required this.onTap,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Country selector: ${country.name} +${country.dialCode}',
      enabled: onTap != null,
      button: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(ZapSpacing.radius),
          ),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  '+${country.dialCode}',
                  style: ZapTypography.bodyLarge.copyWith(
                    color: ZapColors.textPrimary,
                    fontFamily: 'IBMPlexMono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: ZapSpacing.xs),
                const Icon(
                  Icons.expand_more_rounded,
                  color: ZapColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Live grouping formatter ──────────────────────────────────────────────
//
// Inserts spaces as the user types, matching the country convention:
//   IN  → 98765 43210
//   US  → 415 555 0132
//   GB  → 7700 900123
//   AE  → 50 123 4567
// The formatter only ever inserts spaces — never moves digits — so the
// caret math stays simple.

class _GroupingFormatter extends TextInputFormatter {
  final Country country;
  const _GroupingFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(' ', '');
    final groups = _groupsFor(country.iso, raw.length);
    final out = StringBuffer();
    var i = 0;
    for (final size in groups) {
      if (i >= raw.length) break;
      if (i > 0) out.write(' ');
      out.write(raw.substring(i, (i + size).clamp(0, raw.length)));
      i += size;
    }
    // Anything left over (over-typed beyond max grouping) — append raw.
    if (i < raw.length) {
      if (out.isNotEmpty) out.write(' ');
      out.write(raw.substring(i));
    }
    final formatted = out.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Groups for a country at the current input length. Returns the list
  /// of group sizes the formatter should apply.
  List<int> _groupsFor(String iso, int len) {
    switch (iso) {
      case 'IN':
        return const [5, 5]; // 98765 43210
      case 'US':
      case 'CA':
        return const [3, 3, 4]; // 415 555 0132
      case 'GB':
        return const [4, 6]; // 7700 900123
      case 'AE':
        return const [2, 3, 4]; // 50 123 4567
      case 'SG':
        return const [4, 4]; // 9123 4567
      case 'AU':
        return const [3, 3, 3]; // 412 345 678
      default:
        return const [3, 3, 4]; // sane default
    }
  }
}
