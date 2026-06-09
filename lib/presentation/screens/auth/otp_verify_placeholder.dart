import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/zap_badge.dart';
import '../../widgets/zap_button.dart';
import '../../widgets/zap_card.dart';

/// Placeholder shown after a successful OTP request on Day 7. Confirms to the
/// user that the SMS is on its way, mirrors back the phone we sent it to,
/// and reserves the slot for the full 6-digit code entry screen built on
/// Day 8.
///
/// Accepts `extra` from the previous route — `{phone: ..., expiresIn: ...}`.
class OtpVerifyPlaceholderScreen extends StatelessWidget {
  final String phone;
  final int expiresIn;

  const OtpVerifyPlaceholderScreen({
    super.key,
    required this.phone,
    required this.expiresIn,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: ZapSpacing.lg),

              // Hero icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                  border: Border.all(color: ZapColors.safe.withOpacity(0.3), width: 1),
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  color: ZapColors.safe,
                  size: 32,
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),

              Text(
                'Check your messages',
                style: ZapTypography.displaySmall.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
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
                      text: phone,
                      style: ZapTypography.bodyLarge.copyWith(
                        color: ZapColors.textPrimary,
                        fontFamily: 'IBMPlexMono',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '. Enter it below to sign in.'),
                  ],
                ),
              ),

              const SizedBox(height: ZapSpacing.xxxl),

              // Day 8 stub card
              ZapCard(
                backgroundColor: ZapColors.info.withOpacity(0.06),
                borderColor: ZapColors.info.withOpacity(0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.construction_rounded, color: ZapColors.info, size: 20),
                        SizedBox(width: ZapSpacing.sm),
                        ZapBadge(label: 'DAY 8 · BUILDING TOMORROW', intent: ZapBadgeIntent.info),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.md),
                    Text(
                      'OTP entry field, auto-submit, resend timer, paste-from-clipboard, and SMS auto-fill ship on Day 8.',
                      style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.md),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: ZapColors.textSecondary, size: 14),
                        const SizedBox(width: ZapSpacing.xs),
                        Text(
                          'Code expires in ${expiresIn}s · backend ack received',
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: ZapSpacing.xxxl),

              // For now, route the user to the Day 6 lab where they can paste
              // the OTP into the proven verify flow.
              ZapButton.tonal(
                label: 'GO TO VERIFY (DAY 6 LAB)',
                icon: Icons.api_rounded,
                intent: ZapButtonIntent.info,
                fullWidth: true,
                onPressed: () => context.go('/day6'),
              ),
              const SizedBox(height: ZapSpacing.md),
              ZapButton.text(
                label: 'Use a different number',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
