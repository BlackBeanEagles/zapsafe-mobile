import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../widgets/zap_button.dart';
import '../../widgets/zap_badge.dart';

/// Reusable placeholder scaffold — every Day 5 placeholder screen uses this
/// to advertise "I exist, here's what I'll do, here's when I'll be built".
class PlaceholderScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String dayBuilt;
  final String summary;
  final List<String> features;

  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.dayBuilt,
    required this.summary,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              // Hero icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(ZapSpacing.xxl),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(icon, color: accent, size: 56),
                ),
              ),
              const SizedBox(height: ZapSpacing.xxl),

              // Heading + badge
              Center(
                child: Text(
                  title,
                  style: ZapTypography.displaySmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              Center(
                child: ZapBadge(
                  label: 'BUILT IN $dayBuilt',
                  intent: ZapBadgeIntent.info,
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(height: ZapSpacing.xxl),

              // Summary
              Container(
                padding: const EdgeInsets.all(ZapSpacing.lg),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                  border: Border.all(color: ZapColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined, color: accent, size: 20),
                        const SizedBox(width: ZapSpacing.sm),
                        Text(
                          'PURPOSE',
                          style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.textSecondary,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      summary,
                      style: ZapTypography.bodyLarge.copyWith(
                        color: ZapColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),

              // Features list
              Container(
                padding: const EdgeInsets.all(ZapSpacing.lg),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                  border: Border.all(color: ZapColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: accent, size: 20),
                        const SizedBox(width: ZapSpacing.sm),
                        Text(
                          'WHAT THIS SCREEN WILL DO',
                          style: ZapTypography.labelSmall.copyWith(
                            color: ZapColors.textSecondary,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.md),
                    ...features.map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: ZapSpacing.md),
                              Expanded(
                                child: Text(
                                  f,
                                  style: ZapTypography.bodyMedium.copyWith(
                                    color: ZapColors.textPrimary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'BACK TO NAVIGATION INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}
