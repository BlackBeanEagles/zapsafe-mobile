import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/countries.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/country.dart';
import '../../../domain/providers/auth_providers.dart';
import '../../../domain/state/auth_state.dart';
import '../../widgets/phone_input.dart';
import '../../widgets/zap_button.dart';
import '../../widgets/zap_snackbar.dart';

/// Day 7 — Phone Entry Screen
///
/// First screen of the real onboarding flow:
/// 1. User picks country (default India).
/// 2. User enters phone number.
/// 3. We validate against [Country] rules (length, first digit).
/// 4. POST /auth/register/ via [AuthNotifier.requestOtp].
/// 5. On success, navigate to /otp-verify with phone + expiry as extra.
///
/// Layered safety:
/// - Disabled "Send OTP" until input is valid (no API spam for typos).
/// - Backend rate-limit error → shown inline so user knows to wait.
/// - On API failure: user stays here, error in a snackbar, can retry.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _digitsCtrl = TextEditingController();
  Country _country = Countries.defaultCountry;
  String? _error;
  bool _submitting = false;
  bool _touched = false;

  @override
  void dispose() {
    _digitsCtrl.dispose();
    super.dispose();
  }

  String get _digits => _digitsCtrl.text.replaceAll(' ', '');
  bool get _looksValid => _country.validate(_digits) == null && _digits.isNotEmpty;

  void _onChanged(String cleaned) {
    setState(() {
      _touched = _touched || cleaned.isNotEmpty;
      // Only show errors after the user has typed something — don't yell at
      // them while the field is still empty.
      _error = _touched ? _country.validate(cleaned) : null;
    });
  }

  void _onCountryChanged(Country c) {
    setState(() {
      _country = c;
      _error = null;
      _touched = false;
    });
  }

  Future<void> _submit() async {
    if (!_looksValid || _submitting) return;

    final phone = _country.e164(_digits);
    setState(() => _submitting = true);

    final res = await ref.read(authStateProvider.notifier).requestOtp(phone);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res != null) {
      ZapSnackbar.success(
        context,
        'OTP sent. Expires in ${res.expiresIn}s.',
      );
      // Pass phone + expiry to the verify screen via go_router extras.
      context.push('/otp-verify', extra: {
        'phone': phone,
        'expiresIn': res.expiresIn,
      });
      return;
    }

    final s = ref.read(authStateProvider);
    if (s is AuthFailure) {
      // Surface the backend's error code as a hint (e.g. RATE_LIMITED).
      ZapSnackbar.danger(context, s.message);
      ref.read(authStateProvider.notifier).clearError();
    } else {
      ZapSnackbar.danger(context, 'Could not send OTP. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: ZapSpacing.lg),

                // ─── Hero ───────────────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ZapColors.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ZapSpacing.radius),
                    border: Border.all(color: ZapColors.danger.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: ZapColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xl),
                Semantics(
                  label: "Enter your phone number to verify your identity",
                  child: Text(
                    "What's your phone number?",
                    style: ZapTypography.displaySmall.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  "We'll text you a 6-digit code to verify it. ZapSafe never shares "
                  "your number with anyone — even your emergency contacts only see "
                  "what you choose to share.",
                  style: ZapTypography.bodyLarge.copyWith(
                    color: ZapColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: ZapSpacing.xxxl),

                // ─── Input ──────────────────────────────────────────────
                PhoneInput(
                  country: _country,
                  onCountryChanged: _onCountryChanged,
                  controller: _digitsCtrl,
                  errorText: _error,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _submit(),
                  enabled: !_submitting,
                  autofocus: true,
                ),

                const SizedBox(height: ZapSpacing.md),

                // ─── Live preview of the E.164 we'll send ───────────────
                if (_digits.isNotEmpty)
                  _Preview(country: _country, digits: _digits),

                const SizedBox(height: ZapSpacing.xxxl),

                // ─── Submit button ──────────────────────────────────────
                Semantics(
                  label: 'Send OTP to your phone number',
                  enabled: _looksValid && !_submitting,
                  button: true,
                  onTap: (_looksValid && !_submitting) ? _submit : null,
                  child: ZapButton.elevated(
                    label: _submitting ? '' : 'SEND OTP',
                    icon: Icons.send_rounded,
                    size: ZapButtonSize.large,
                    fullWidth: true,
                    isLoading: _submitting,
                    onPressed: (_looksValid && !_submitting) ? _submit : null,
                  ),
                ),

                const SizedBox(height: ZapSpacing.md),

                // ─── Legal microcopy ────────────────────────────────────
                const _LegalNote(),

                const SizedBox(height: ZapSpacing.huge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inline preview of normalized E.164 ─────────────────────────────────

class _Preview extends StatelessWidget {
  final Country country;
  final String digits;
  const _Preview({required this.country, required this.digits});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt_rounded, color: ZapColors.info, size: 14),
        const SizedBox(width: ZapSpacing.xs),
        Text(
          'Will send to: ',
          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
        ),
        Text(
          country.e164(digits),
          style: ZapTypography.monoSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Privacy / terms microcopy ──────────────────────────────────────────

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lock_outline_rounded, color: ZapColors.textMuted, size: 14),
        const SizedBox(width: ZapSpacing.xs),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              children: [
                const TextSpan(text: 'By tapping Send OTP, you agree to our '),
                TextSpan(
                  text: 'Terms',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.info,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.info,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: '. Standard SMS rates may apply.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
