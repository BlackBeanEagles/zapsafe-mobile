import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';

/// Day 39 — simple 4-digit PIN entry widget.
///
/// Visually similar to the 6-digit OTP boxes (Day 8) but smaller and
/// configured for secret input: digits are masked with `•` after typing,
/// no paste-from-clipboard helper, no auto-submit on full entry.
///
/// Callers receive an `onChanged(String pin)` callback as the user types.
/// When the user hits enter or the parent triggers a confirm, the parent
/// reads the latest value off the controller via `controller.text`.
class ZapPinEntry extends StatefulWidget {
  /// Number of digits — defaults to 4. Production PINs are 4 or 6; the
  /// SDK supports both.
  final int length;

  /// Called on every change. Parent typically uses this to enable a
  /// "CONFIRM" button only once `pin.length == widget.length`.
  final ValueChanged<String>? onChanged;

  /// Called once the user has entered all [length] digits. The pin is
  /// passed un-masked; the widget keeps showing dots.
  final ValueChanged<String>? onComplete;

  /// Optional external controller so the parent can clear / preset the
  /// value (e.g. on dialog re-show). When null the widget owns one.
  final TextEditingController? controller;

  final FocusNode? focusNode;

  /// Set to false once the parent has accepted the PIN — disables input
  /// without unmounting the widget. Defaults to true.
  final bool enabled;

  /// Render the boxes in red to indicate a failed attempt. The boxes
  /// auto-clear on next keystroke.
  final bool error;

  const ZapPinEntry({
    super.key,
    this.length = 4,
    this.onChanged,
    this.onComplete,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.error = false,
  });

  @override
  State<ZapPinEntry> createState() => _ZapPinEntryState();
}

class _ZapPinEntryState extends State<ZapPinEntry> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController();
      _ownsController = true;
    } else {
      _controller = widget.controller!;
    }
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _ownsFocus = true;
    } else {
      _focusNode = widget.focusNode!;
    }
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length) {
      widget.onComplete?.call(text);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    if (_ownsController) _controller.dispose();
    if (_ownsFocus) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text;
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Column(
        children: [
          // Visible boxes.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < widget.length; i++) ...[
                _PinBox(
                  filled: i < value.length,
                  active: i == value.length && _focusNode.hasFocus,
                  error: widget.error,
                ),
                if (i < widget.length - 1)
                  const SizedBox(width: ZapSpacing.sm),
              ],
            ],
          ),
          // Off-screen real text field that owns the keyboard. We size it
          // to zero but keep it tappable so accessibility focuses route
          // here correctly.
          SizedBox(
            height: 0,
            width: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              autofocus: false,
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  final bool filled;
  final bool active;
  final bool error;

  const _PinBox({
    required this.filled,
    required this.active,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final border = error
        ? ZapColors.danger
        : (active ? ZapColors.info : ZapColors.border);
    return Container(
      width: 52,
      height: 64,
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: border, width: active ? 2 : 1),
      ),
      alignment: Alignment.center,
      child: filled
          ? Text('•',
              style: ZapTypography.displaySmall.copyWith(
                color: error ? ZapColors.danger : ZapColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ))
          : null,
    );
  }
}
