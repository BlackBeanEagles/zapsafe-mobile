import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/providers/auth_providers.dart';
import '../../../domain/state/auth_state.dart';
import '../../widgets/zap_button.dart';
import '../../widgets/zap_snackbar.dart';

const _kOtpLength = 6;

/// Day 8 — OTP Verify Screen
///
/// Receives `phone` + `expiresIn` from PhoneEntryScreen via go_router extras.
/// Flow:
///   1. User types/pastes the 6-digit code.
///   2. On 6th digit → auto-submits.
///   3. Correct → AuthNotifier flips to AuthAuthenticated → router guard sends
///      user to dashboard.
///   4. Wrong / expired → error shown, fields cleared, user retypes.
///   5. Timer counts down from [expiresIn]. When 0, Resend OTP enabled.
///
/// Security: passcode fields use obscureText = false (it's a short-lived OTP,
/// showing the digit makes UX much faster) but the submit path always sends
/// the raw digit string — no formatting, no spaces.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  final int expiresIn;

  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.expiresIn,
  });

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  // One controller + one focus node per digit.
  final _controllers = List.generate(_kOtpLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_kOtpLength, (_) => FocusNode());

  String? _errorText;
  bool _submitting = false;

  // Resend timer
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.expiresIn;
    _startTimer();
    // Auto-focus first field after the frame settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  // ─── Timer ────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ─── Digit entry logic ────────────────────────────────────────────────

  String get _currentOtp =>
      _controllers.map((c) => c.text).join();

  bool get _isComplete => _currentOtp.length == _kOtpLength;

  void _onDigitChanged(int index, String value) {
    // Allow paste — if a full 6-digit string lands in a field, distribute.
    final stripped = value.replaceAll(RegExp(r'\D'), '');
    if (stripped.length > 1) {
      _distributePaste(stripped);
      return;
    }

    setState(() {
      _errorText = null;
    });

    if (value.isEmpty) {
      // Backspace: move focus left if not already on the first field.
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    // Normal digit: advance focus.
    if (index < _kOtpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      // Last digit filled — auto-submit.
      _focusNodes[index].unfocus();
      _submit();
    }
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;
    // If the current field is already empty, move focus left and clear that
    // field — standard OTP UX backspace behaviour.
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() => _errorText = null);
    }
  }

  /// Handles clipboard paste: takes up to [_kOtpLength] digits and fills boxes.
  void _distributePaste(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < _kOtpLength; i++) {
      if (i < clean.length) {
        _controllers[i].text = clean[i];
      } else {
        _controllers[i].clear();
      }
    }
    // Focus the field after the last pasted digit, or unfocus if all filled.
    final lastFilled = clean.length < _kOtpLength ? clean.length : _kOtpLength - 1;
    if (clean.length >= _kOtpLength) {
      _focusNodes[lastFilled].unfocus();
      _submit();
    } else {
      _focusNodes[lastFilled].requestFocus();
    }
    setState(() => _errorText = null);
  }

  /// Manually paste from clipboard button handler.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty) {
      _distributePaste(text);
    }
  }

  // ─── Submission ───────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting || !_isComplete) return;
    final otp = _currentOtp;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final ok = await ref.read(authStateProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: otp,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      // Router redirect (isLoggedInProvider → true) will push to /dashboard.
      // Explicit go() is a safety net in case the redirect fires before this.
      context.go('/dashboard');
      return;
    }

    // Extract error from state.
    final s = ref.read(authStateProvider);
    String msg = 'Incorrect code. Please try again.';
    if (s is AuthFailure) {
      if (s.code == 'OTP_EXPIRED' || s.message.toLowerCase().contains('expir')) {
        msg = 'Code expired. Tap Resend to get a new one.';
        setState(() => _errorText = msg);
        _clearAndRefocus();
        ref.read(authStateProvider.notifier).clearError();
        return;
      }
      msg = s.message;
      ref.read(authStateProvider.notifier).clearError();
    }

    // Wrong OTP: show error, clear fields, re-focus first box.
    setState(() => _errorText = msg);
    _clearAndRefocus();
  }

  void _clearAndRefocus() {
    for (final c in _controllers) {
      c.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  // ─── Resend ───────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _submitting) return;

    setState(() => _submitting = true);

    final res = await ref.read(authStateProvider.notifier).requestOtp(widget.phone);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res != null) {
      setState(() {
        _secondsLeft = res.expiresIn;
        _errorText = null;
      });
      _startTimer();
      ZapSnackbar.success(context, 'New code sent. Expires in ${res.expiresIn}s.');
      _clearAndRefocus();
      return;
    }

    final s = ref.read(authStateProvider);
    if (s is AuthFailure) {
      ZapSnackbar.danger(context, s.message);
      ref.read(authStateProvider.notifier).clearError();
    } else {
      ZapSnackbar.danger(context, 'Could not resend. Try again.');
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0 && !_submitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/phone-entry'),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: ZapSpacing.lg),

                // ─── Hero ──────────────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ZapSpacing.radius),
                    border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.sms_rounded, color: ZapColors.safe, size: 32),
                ),
                const SizedBox(height: ZapSpacing.xl),

                Semantics(
                  header: true,
                  label: 'Enter the 6-digit code sent to your phone',
                  child: Text(
                    'Check your messages',
                    style: ZapTypography.displaySmall.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text.rich(
                  TextSpan(
                    style: ZapTypography.bodyLarge.copyWith(
                      color: ZapColors.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to '),
                      TextSpan(
                        text: widget.phone,
                        style: ZapTypography.bodyLarge.copyWith(
                          color: ZapColors.textPrimary,
                          fontFamily: 'IBMPlexMono',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),

                const SizedBox(height: ZapSpacing.xxxl),

                // ─── 6-digit boxes ─────────────────────────────────────
                Semantics(
                  label: 'Six digit verification code input',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _kOtpLength,
                      (i) => _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        hasError: _errorText != null,
                        enabled: !_submitting,
                        index: i,
                        onChanged: (v) => _onDigitChanged(i, v),
                        onKeyEvent: (e) => _onKeyDown(i, e),
                      ),
                    ),
                  ),
                ),

                // ─── Error label ───────────────────────────────────────
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: ZapSpacing.sm),
                    child: Semantics(
                      liveRegion: true,
                      label: 'Error: $_errorText',
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: ZapColors.error, size: 14),
                          const SizedBox(width: ZapSpacing.xs),
                          Expanded(
                            child: Text(
                              _errorText!,
                              style: ZapTypography.bodySmall
                                  .copyWith(color: ZapColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: ZapSpacing.md),

                // ─── Paste helper ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _submitting ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: const Text('Paste code'),
                    style: TextButton.styleFrom(
                      foregroundColor: ZapColors.info,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.sm,
                        vertical: ZapSpacing.xs,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: ZapSpacing.xl),

                // ─── Submit button ─────────────────────────────────────
                Semantics(
                  label: 'Verify code and sign in',
                  enabled: _isComplete && !_submitting,
                  button: true,
                  child: ZapButton.elevated(
                    label: _submitting ? '' : 'VERIFY',
                    icon: Icons.verified_user_rounded,
                    size: ZapButtonSize.large,
                    fullWidth: true,
                    isLoading: _submitting,
                    onPressed: (_isComplete && !_submitting) ? _submit : null,
                  ),
                ),

                const SizedBox(height: ZapSpacing.xxxl),

                // ─── Resend + timer ────────────────────────────────────
                _ResendRow(
                  secondsLeft: _secondsLeft,
                  canResend: canResend,
                  onResend: _resend,
                ),

                const SizedBox(height: ZapSpacing.huge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Individual OTP digit box ──────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool enabled;
  final int index;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.enabled,
    required this.index,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Digit ${index + 1} of $_kOtpLength',
      textField: true,
      child: SizedBox(
        width: 46,
        height: 58,
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: onKeyEvent,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            cursorColor: ZapColors.info,
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              fontFamily: 'IBMPlexMono',
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: hasError
                  ? ZapColors.error.withOpacity(0.08)
                  : ZapColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide: BorderSide(
                  color: hasError ? ZapColors.error : ZapColors.border,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide: BorderSide(
                  color: hasError ? ZapColors.error : ZapColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide: BorderSide(
                  color: hasError ? ZapColors.error : ZapColors.info,
                  width: 2.0,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide:
                    BorderSide(color: ZapColors.border.withOpacity(0.4), width: 1),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

// ─── Resend row ────────────────────────────────────────────────────────────

class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final bool canResend;
  final VoidCallback onResend;

  const _ResendRow({
    required this.secondsLeft,
    required this.canResend,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't get the code?  ",
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
        ),
        if (!canResend) ...[
          Semantics(
            label: 'Resend available in $secondsLeft seconds',
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: ZapColors.textMuted, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${secondsLeft}s',
                  style: ZapTypography.monoSmall.copyWith(
                    color: ZapColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Semantics(
            label: 'Resend verification code',
            button: true,
            child: GestureDetector(
              onTap: onResend,
              child: Text(
                'Resend OTP',
                style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.info,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: ZapColors.info,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
