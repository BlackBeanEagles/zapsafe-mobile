import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// ZapSafe text input.
///
/// Wraps Flutter's [TextField] with the design system's look + a few
/// safety-app conveniences (helper text, char counter, password reveal,
/// validation state colors).
///
/// Usage:
/// ```dart
/// ZapTextField(
///   label: 'Phone number',
///   hint: '+91 98765 43210',
///   prefixIcon: Icons.phone,
///   keyboardType: TextInputType.phone,
///   onChanged: (v) => setState(() => phone = v),
/// )
/// ```
class ZapTextField extends StatefulWidget {
  /// Floating label text.
  final String label;

  /// Placeholder shown when empty + unfocused.
  final String? hint;

  /// Help text shown below the field (not an error).
  final String? helperText;

  /// Error message — shows below the field, switches border + label to red.
  final String? errorText;

  /// Icon shown on the left.
  final IconData? prefixIcon;

  /// Icon shown on the right (e.g. clear button).
  final IconData? suffixIcon;

  /// Tapped when [suffixIcon] is pressed.
  final VoidCallback? onSuffixTap;

  /// Hide input (passwords, PINs). Adds an eye toggle in the suffix.
  final bool obscureText;

  /// Restrict input to a specific keyboard type.
  final TextInputType? keyboardType;

  /// Apply formatters (e.g. digits-only, max length).
  final List<TextInputFormatter>? inputFormatters;

  /// External controller. If null, an internal one is created.
  final TextEditingController? controller;

  /// Called on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (enter key on physical keyboard).
  final ValueChanged<String>? onSubmitted;

  /// Disable interaction (greys out the field).
  final bool enabled;

  /// Allow multiple lines. If >1, the field grows to fit.
  final int maxLines;

  /// Max chars allowed.
  final int? maxLength;

  /// Start with focus already on the field.
  final bool autofocus;

  const ZapTextField({
    super.key,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
  });

  @override
  State<ZapTextField> createState() => _ZapTextFieldState();
}

class _ZapTextFieldState extends State<ZapTextField> {
  late final FocusNode _focusNode;
  late TextEditingController _controller;
  bool _ownsController = false;
  bool _focused = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocus);
    if (widget.controller == null) {
      _controller = TextEditingController();
      _ownsController = true;
    } else {
      _controller = widget.controller!;
    }
  }

  void _onFocus() => setState(() => _focused = _focusNode.hasFocus);

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Color _borderColor() {
    if (widget.errorText != null) return ZapColors.error;
    if (_focused) return ZapColors.info;
    return ZapColors.border;
  }

  Color _labelColor() {
    if (widget.errorText != null) return ZapColors.error;
    if (_focused) return ZapColors.info;
    return ZapColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final showEye = widget.obscureText;
    final effectiveObscure = widget.obscureText && !_revealed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Label ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: ZapSpacing.xs, bottom: ZapSpacing.sm),
          child: Text(
            widget.label,
            style: ZapTypography.labelMedium.copyWith(
              color: _labelColor(),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // ─── Field ─────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: _borderColor(),
              width: _focused || hasError ? 2.0 : 1.0,
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: effectiveObscure,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            cursorColor: ZapColors.info,
            style: ZapTypography.bodyLarge.copyWith(color: ZapColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: ZapTypography.bodyLarge.copyWith(color: ZapColors.textMuted),
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? ZapSpacing.sm : ZapSpacing.lg,
                vertical: ZapSpacing.lg,
              ),
              isCollapsed: false,
              isDense: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              counterText: '',
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: ZapSpacing.md, right: ZapSpacing.sm),
                      child: Icon(
                        widget.prefixIcon,
                        color: _focused ? ZapColors.info : ZapColors.textSecondary,
                        size: 22,
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: showEye
                  ? IconButton(
                      icon: Icon(
                        _revealed ? Icons.visibility_off : Icons.visibility,
                        color: ZapColors.textSecondary,
                        size: 22,
                      ),
                      onPressed: () => setState(() => _revealed = !_revealed),
                      tooltip: _revealed ? 'Hide' : 'Show',
                    )
                  : widget.suffixIcon == null
                      ? null
                      : IconButton(
                          icon: Icon(widget.suffixIcon, color: ZapColors.textSecondary, size: 22),
                          onPressed: widget.onSuffixTap,
                        ),
            ),
          ),
        ),

        // ─── Helper / error / counter row ──────────────────────────
        if (widget.helperText != null || hasError || widget.maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: ZapSpacing.sm, left: ZapSpacing.xs, right: ZapSpacing.xs),
            child: Row(
              children: [
                if (hasError)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: ZapColors.error, size: 14),
                        const SizedBox(width: ZapSpacing.xs),
                        Expanded(
                          child: Text(
                            widget.errorText!,
                            style: ZapTypography.bodySmall.copyWith(color: ZapColors.error),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.helperText != null)
                  Expanded(
                    child: Text(
                      widget.helperText!,
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                    ),
                  )
                else
                  const Spacer(),
                if (widget.maxLength != null)
                  Text(
                    '${_controller.text.length}/${widget.maxLength}',
                    style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
