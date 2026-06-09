import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_text_field.dart';
import '../widgets/zap_badge.dart';
import '../widgets/protection_score_ring.dart';

/// Day 4 — Reusable Widget Library Showcase
///
/// Demonstrates ZapButton, ZapCard, ZapTextField, ZapBadge,
/// ProtectionScoreRing — the five widgets that will be used everywhere.
class Day4WidgetsShowcaseScreen extends StatefulWidget {
  const Day4WidgetsShowcaseScreen({super.key});

  @override
  State<Day4WidgetsShowcaseScreen> createState() => _Day4WidgetsShowcaseScreenState();
}

class _Day4WidgetsShowcaseScreenState extends State<Day4WidgetsShowcaseScreen> {
  int _score = 85;
  bool _loadingDemo = false;
  String? _phoneError;
  Timer? _scoreTimer;

  @override
  void initState() {
    super.initState();
    // Auto-animate the score ring through different tiers every 4s so the user
    // can see all colors without tapping.
    _scoreTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        const scores = [85, 65, 35, 12, 70];
        final idx = (scores.indexOf(_score) + 1) % scores.length;
        _score = scores[idx];
      });
    });
  }

  @override
  void dispose() {
    _scoreTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerLoadingDemo() async {
    setState(() => _loadingDemo = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loadingDemo = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Done! (this was a demo)')),
    );
  }

  void _validatePhone(String v) {
    final ok = v.isEmpty || v.length >= 10;
    setState(() => _phoneError = ok ? null : 'Phone must be at least 10 digits');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Day 4 · Widget Library')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Banner(),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Protection Score Ring ───────────────────────────────
            const _SectionTitle('PROTECTION SCORE RING'),
            const SizedBox(height: ZapSpacing.lg),
            Center(
              child: ProtectionScoreRing(
                score: _score,
                size: 220,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Score detail (current: $_score)')),
                  );
                },
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            Center(
              child: Text(
                'Auto-cycling through tiers · tap to manually open detail',
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            Center(
              child: Wrap(
                spacing: ZapSpacing.sm,
                children: [85, 65, 35, 12].map((s) {
                  return ChoiceChip(
                    label: Text('$s'),
                    selected: _score == s,
                    onSelected: (_) => setState(() => _score = s),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: ZapSpacing.huge),

            // ─── ZapBadge ───────────────────────────────────────────
            const _SectionTitle('ZAP BADGE · status pills'),
            const SizedBox(height: ZapSpacing.lg),
            const Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              children: [
                ZapBadge(label: 'SAFE', intent: ZapBadgeIntent.safe, icon: Icons.check_circle),
                ZapBadge(label: 'ELEVATED', intent: ZapBadgeIntent.warning, icon: Icons.warning),
                ZapBadge(label: 'CRITICAL', intent: ZapBadgeIntent.danger, icon: Icons.error),
                ZapBadge(label: 'TIER 1', intent: ZapBadgeIntent.info),
                ZapBadge(label: 'PENDING', intent: ZapBadgeIntent.neutral),
                ZapBadge.filled(label: 'SOS ACTIVE', icon: Icons.notifications_active, pulse: true),
                ZapBadge.outlined(label: 'VERIFIED', intent: ZapBadgeIntent.safe, icon: Icons.verified),
                ZapBadge.outlined(label: 'LP24 · TRUSTED', intent: ZapBadgeIntent.info),
              ],
            ),
            const SizedBox(height: ZapSpacing.huge),

            // ─── ZapButton ──────────────────────────────────────────
            const _SectionTitle('ZAP BUTTON · 4 variants × 5 intents'),
            const SizedBox(height: ZapSpacing.lg),
            Wrap(
              spacing: ZapSpacing.md,
              runSpacing: ZapSpacing.md,
              children: [
                ZapButton.elevated(
                  label: 'TRIGGER SOS',
                  icon: Icons.warning,
                  onPressed: () {},
                ),
                ZapButton.elevated(
                  label: 'VERIFY',
                  icon: Icons.check,
                  intent: ZapButtonIntent.safe,
                  onPressed: () {},
                ),
                ZapButton.tonal(
                  label: 'LEARN MORE',
                  intent: ZapButtonIntent.info,
                  onPressed: () {},
                ),
                ZapButton.outlined(
                  label: 'CANCEL',
                  onPressed: () {},
                ),
                ZapButton.text(
                  label: 'Skip for now',
                  onPressed: () {},
                ),
                const ZapButton.elevated(
                  label: 'DISABLED',
                  onPressed: null, // disabled
                ),
                ZapButton.elevated(
                  label: _loadingDemo ? '' : 'TRY LOADING',
                  onPressed: _loadingDemo ? null : _triggerLoadingDemo,
                  isLoading: _loadingDemo,
                  intent: ZapButtonIntent.info,
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.lg),
            ZapButton.elevated(
              label: 'FULL-WIDTH · LARGE',
              icon: Icons.shield,
              size: ZapButtonSize.large,
              fullWidth: true,
              onPressed: () {},
            ),
            const SizedBox(height: ZapSpacing.huge),

            // ─── ZapCard ────────────────────────────────────────────
            const _SectionTitle('ZAP CARD · tap to feel the lift'),
            const SizedBox(height: ZapSpacing.lg),
            ZapCard(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card tapped')),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: ZapColors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ZapSpacing.radius),
                    ),
                    child: const Icon(Icons.contacts, color: ZapColors.danger, size: 28),
                  ),
                  const SizedBox(width: ZapSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aarti Sharma',
                          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        const Row(
                          children: [
                            ZapBadge(
                              label: 'TIER 1',
                              intent: ZapBadgeIntent.danger,
                              size: ZapBadgeSize.small,
                            ),
                            SizedBox(width: ZapSpacing.sm),
                            ZapBadge(
                              label: 'VERIFIED',
                              intent: ZapBadgeIntent.safe,
                              icon: Icons.verified,
                              size: ZapBadgeSize.small,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: ZapColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            ZapCard(
              isHighlighted: true,
              highlightColor: ZapColors.safe,
              onTap: () {},
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: ZapColors.safe, size: 32),
                  const SizedBox(width: ZapSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Highlighted Card',
                          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.safe),
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        Text(
                          'isHighlighted: true · highlightColor: safe',
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            const ZapCard(
              child: Text(
                'A plain non-tappable card. No animation, no shadow on press. Use for static content.',
                style: TextStyle(color: ZapColors.textPrimary),
              ),
            ),
            const SizedBox(height: ZapSpacing.huge),

            // ─── ZapTextField ───────────────────────────────────────
            const _SectionTitle('ZAP TEXT FIELD'),
            const SizedBox(height: ZapSpacing.lg),
            ZapTextField(
              label: 'Phone number',
              hint: '+91 98765 43210',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: _phoneError,
              helperText: 'Used for OTP login and SMS alerts',
              onChanged: _validatePhone,
            ),
            const SizedBox(height: ZapSpacing.lg),
            const ZapTextField(
              label: 'Cancel PIN',
              hint: '6-digit PIN',
              prefixIcon: Icons.lock,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: ZapSpacing.lg),
            const ZapTextField(
              label: 'Emergency Notes',
              hint: 'Allergies, medical conditions, special instructions...',
              prefixIcon: Icons.medical_information,
              maxLines: 3,
              maxLength: 200,
              helperText: 'Visible to contacts during an SOS',
            ),
            const SizedBox(height: ZapSpacing.huge),
            const _FooterBanner(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: ZapColors.safe.withOpacity(0.08),
      borderColor: ZapColors.safe.withOpacity(0.4),
      child: Row(
        children: [
          const Icon(Icons.widgets_rounded, color: ZapColors.safe, size: 28),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day 4 — Widget Library Live',
                  style: ZapTypography.headlineSmall.copyWith(color: ZapColors.safe),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'ZapButton · ZapCard · ZapTextField · ZapBadge · ProtectionScoreRing',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterBanner extends StatelessWidget {
  const _FooterBanner();

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: ZapColors.info.withOpacity(0.08),
      borderColor: ZapColors.info.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.east, color: ZapColors.info, size: 22),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                'Next: Day 5',
                style: ZapTypography.headlineSmall.copyWith(color: ZapColors.info),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'ZapSnackbar · ZapDialog · ZapChip + go_router navigation setup',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
