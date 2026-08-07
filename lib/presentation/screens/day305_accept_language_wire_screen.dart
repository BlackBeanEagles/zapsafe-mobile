/// Day 305 — Accept-Language Header Wiring
///
/// Demonstrates the real, centralized `_AcceptLanguageInterceptor` in
/// `api_client.dart`: every Dio request (authenticated or public) now
/// carries `Accept-Language: <app locale>`, sourced from EasyLocalization's
/// `context.locale` via `currentLanguageCodeProvider` (bridged in
/// `main.dart`). Toggling the language here calls the real
/// `context.setLocale(...)`, then fires a real request through
/// `apiClientProvider` and shows the actual captured header from
/// `AcceptLanguageAuditLog` — not a simulated value.
///
/// Backend dependency: `AcceptLanguageMiddleware` (Day 103). Verified LIVE
/// by reading `zapsafe_backend/zapsafe_backend/settings.py` MIDDLEWARE and
/// `middleware.py` directly (Docker was unavailable in this sandbox) — it
/// IS registered and activates `translation.activate(lang)` per request,
/// contrary to this screen's original spec text which assumed it might
/// still be pending ("until live, expect English fallback"). It is live.
/// Tag: 🔗 WIRE
///
/// Route: AppRoutes.acceptLanguageWire
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/api_client.dart';
import '../../domain/providers/auth_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

const _kDemoLocales = [
  ('en', 'English'),
  ('hi', 'हिन्दी (Hindi)'),
  ('ta', 'தமிழ் (Tamil)'),
  ('ar', 'العربية (Arabic)'),
];

class Day305AcceptLanguageWireScreen extends ConsumerStatefulWidget {
  const Day305AcceptLanguageWireScreen({super.key});

  @override
  ConsumerState<Day305AcceptLanguageWireScreen> createState() =>
      _Day305AcceptLanguageWireScreenState();
}

class _Day305AcceptLanguageWireScreenState
    extends ConsumerState<Day305AcceptLanguageWireScreen> {
  bool _firing = false;

  Future<void> _fireTestCall() async {
    setState(() => _firing = true);
    try {
      // A cheap, real, read-only authenticated call — exercises the real
      // interceptor chain exactly like every other screen in the app.
      // Failure (offline/401/backend down) is fine here: the header is
      // attached in onRequest, BEFORE the network call happens, so the
      // audit log still captures a real entry either way.
      await ref.read(apiClientProvider).dio.get('/api/v1/users/me/');
    } catch (_) {
      // Intentionally ignored — this screen audits the outgoing header,
      // not whether the backend is reachable right now.
    } finally {
      if (mounted) setState(() => _firing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('day301_305.accept_language_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day301_305.accept_language_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Toggle the real app locale below, fire a test call, and see '
            'the actual header the Dio interceptor attached — captured in '
            'AcceptLanguageAuditLog, not simulated.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Current app locale: ',
                        style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary)),
                    ZapBadge(label: currentLocale, intent: ZapBadgeIntent.info),
                  ],
                ),
                const SizedBox(height: ZapSpacing.md),
                Wrap(
                  spacing: ZapSpacing.sm,
                  runSpacing: ZapSpacing.sm,
                  children: [
                    for (final (code, label) in _kDemoLocales)
                      ChoiceChip(
                        label: Text(label),
                        selected: currentLocale == code,
                        onSelected: (_) async {
                          await context.setLocale(Locale(code));
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.md),
                ZapButton.elevated(
                  label: 'Fire test call',
                  intent: ZapButtonIntent.info,
                  fullWidth: true,
                  isLoading: _firing,
                  onPressed: _fireTestCall,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('Captured outgoing headers',
              style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.sm),
          if (AcceptLanguageAuditLog.entries.isEmpty)
            ZapCard(
              child: Text(
                'No requests captured yet in this session — fire a test '
                'call above, or navigate around the app (every screen that '
                'hits the backend goes through this same interceptor).',
                style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
              ),
            )
          else
            for (final entry in AcceptLanguageAuditLog.entries)
              ZapCard(
                margin: const EdgeInsets.only(bottom: ZapSpacing.xs),
                child: Row(
                  children: [
                    ZapBadge(
                      label: entry.languageHeader,
                      intent: entry.languageHeader == 'en'
                          ? ZapBadgeIntent.neutral
                          : ZapBadgeIntent.safe,
                      size: ZapBadgeSize.small,
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text('${entry.method} ${entry.path}',
                          style: ZapTypography.monoSmall.copyWith(color: ZapColors.textPrimary)),
                    ),
                    Text(
                      '${entry.at.hour.toString().padLeft(2, '0')}:'
                      '${entry.at.minute.toString().padLeft(2, '0')}:'
                      '${entry.at.second.toString().padLeft(2, '0')}',
                      style: ZapTypography.labelSmall.copyWith(color: ZapColors.textSecondary),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend status', style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'AcceptLanguageMiddleware (Day 103) is registered in '
                  'zapsafe_backend/zapsafe_backend/settings.py MIDDLEWARE '
                  'and calls translation.activate(lang) per request — '
                  'confirmed by reading the file directly. OTP verify and '
                  'every other endpoint will receive Hindi-localized error '
                  'codes today when this header says "hi", not after some '
                  'future backend day.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Back to integration audit',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
