/// Day 351 — Enterprise SSO Login Preview
///
/// Section K (Days 351-360, "Enterprise & B2B"): a provider picker for a
/// future employer-SSO login flow (SAML/OAuth), for B2B pilot demos.
///
/// Verified against `zapsafe_backend` before building (grepped `enterprise`,
/// `sso`, across every app's `urls.py`/`views.py`): there is no
/// `enterprise` app, no SSO views, and no SAML/OAuth provider model of any
/// kind. The only real auth backend is OTP (`/auth/`) + Google Sign-In
/// (`/auth/google-verify/`, Day 257) — no enterprise identity-provider
/// integration exists. This screen is a real, clearly-mock UI: tapping any
/// provider simulates the redirect → callback → JWT-issue flow with a fake
/// delay, never a live network call.
///
/// Future API contract this screen is built against (not implemented
/// anywhere yet — this is this screen's own proposal for what a real
/// implementation would need):
///   GET  /api/v1/enterprise/sso/providers/
///     -> [{"id", "name", "protocol": "saml"|"oauth2", "logo_url"}]
///   POST /api/v1/enterprise/sso/start/  body: {"provider_id"}
///     -> {"redirect_url"} (302 to the IdP; IdP callback exchanges a code
///        for the same JWT access/refresh pair `/auth/verify-otp/` returns
///        today, so downstream token handling needs no new code path)
///
/// Tag: 🟡 MOCK-NOW · no backend enterprise/SSO app exists.
///
/// Route: [AppRoutes.enterpriseSsoPreview] → `/day-351-enterprise-sso-preview`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _SsoProtocol { saml, oauth2 }

class _SsoProvider {
  const _SsoProvider({
    required this.id,
    required this.name,
    required this.protocol,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final _SsoProtocol protocol;
  final IconData icon;
  final Color color;
}

const _kProviders = [
  _SsoProvider(
    id: 'okta',
    name: 'Okta',
    protocol: _SsoProtocol.saml,
    icon: Icons.security_rounded,
    color: Color(0xFF007DC1),
  ),
  _SsoProvider(
    id: 'azure_ad',
    name: 'Microsoft Entra ID (Azure AD)',
    protocol: _SsoProtocol.saml,
    icon: Icons.window_rounded,
    color: Color(0xFF0078D4),
  ),
  _SsoProvider(
    id: 'google_workspace',
    name: 'Google Workspace',
    protocol: _SsoProtocol.oauth2,
    icon: Icons.g_mobiledata_rounded,
    color: Color(0xFF4285F4),
  ),
  _SsoProvider(
    id: 'onelogin',
    name: 'OneLogin',
    protocol: _SsoProtocol.saml,
    icon: Icons.vpn_key_rounded,
    color: Color(0xFFE0111B),
  ),
];

enum _SsoFlowState { idle, redirecting, callback, done }

final _d351SelectedProviderProvider = StateProvider<String?>((ref) => null);
final _d351FlowStateProvider = StateProvider<_SsoFlowState>((ref) => _SsoFlowState.idle);

Future<void> _simulateSsoFlow(WidgetRef ref, String providerId) async {
  ref.read(_d351SelectedProviderProvider.notifier).state = providerId;
  ref.read(_d351FlowStateProvider.notifier).state = _SsoFlowState.redirecting;
  await Future<void>.delayed(const Duration(milliseconds: 700));
  ref.read(_d351FlowStateProvider.notifier).state = _SsoFlowState.callback;
  await Future<void>.delayed(const Duration(milliseconds: 700));
  ref.read(_d351FlowStateProvider.notifier).state = _SsoFlowState.done;
}

void _resetSsoFlow(WidgetRef ref) {
  ref.read(_d351FlowStateProvider.notifier).state = _SsoFlowState.idle;
  ref.read(_d351SelectedProviderProvider.notifier).state = null;
}

class Day351EnterpriseSsoPreviewScreen extends ConsumerWidget {
  const Day351EnterpriseSsoPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(_d351FlowStateProvider);
    final selectedId = ref.watch(_d351SelectedProviderProvider);
    final selectedProvider =
        _kProviders.where((p) => p.id == selectedId).cast<_SsoProvider?>().firstOrNull;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.sso_preview_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded, color: ZapColors.warning, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🟡 MOCK-NOW · Section K Day 1/10 · no enterprise/SSO backend '
                    'exists in zapsafe_backend (verified: no `enterprise` app, no '
                    'SAML/OAuth provider model). Every provider below is a UI '
                    'simulation only — no live redirect, no real IdP call.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.sso_preview_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Choose an identity provider to continue — for B2B pilot demos.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xl),
          if (flowState == _SsoFlowState.idle)
            for (final p in _kProviders)
              ZapCard(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                onTap: () => _simulateSsoFlow(ref, p.id),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(p.icon, color: p.color, size: 22),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Continue with ${p.name}',
                              style: ZapTypography.bodyMedium
                                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                          Text(
                            p.protocol == _SsoProtocol.saml ? 'SAML 2.0' : 'OAuth 2.0 / OIDC',
                            style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: ZapColors.textMuted),
                  ],
                ),
              )
          else
            _SsoFlowCard(state: flowState, provider: selectedProvider, onReset: () => _resetSsoFlow(ref)),
          const SizedBox(height: ZapSpacing.xl),
          Text('FUTURE API CONTRACT (NOT IMPLEMENTED)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: SelectableText(
              _kJsonEncoder.convert({
                'GET /api/v1/enterprise/sso/providers/': [
                  {'id': 'okta', 'name': 'Okta', 'protocol': 'saml', 'logo_url': 'https://...'}
                ],
                'POST /api/v1/enterprise/sso/start/': {
                  'request': {'provider_id': 'okta'},
                  'response': {'redirect_url': 'https://idp.example.com/sso/...'},
                },
              }),
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Copy proposed API contract',
            icon: Icons.copy_rounded,
            fullWidth: true,
            onPressed: () {
              Clipboard.setData(const ClipboardData(
                text: 'GET /api/v1/enterprise/sso/providers/\n'
                    'POST /api/v1/enterprise/sso/start/\n\n'
                    'Neither endpoint exists in zapsafe_backend yet — proposed '
                    'contract for a future enterprise SSO integration.',
              ));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Contract copied')));
            },
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _SsoFlowCard extends StatelessWidget {
  const _SsoFlowCard({required this.state, required this.provider, required this.onReset});

  final _SsoFlowState state;
  final _SsoProvider? provider;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final name = provider?.name ?? 'provider';
    return ZapCard(
      child: Column(
        children: [
          if (state != _SsoFlowState.done)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ZapSpacing.lg),
              child: CircularProgressIndicator(),
            )
          else
            const Icon(Icons.check_circle_rounded, color: ZapColors.safe, size: 48),
          const SizedBox(height: ZapSpacing.md),
          Text(
            switch (state) {
              _SsoFlowState.redirecting => 'Redirecting to $name (simulated)…',
              _SsoFlowState.callback => 'Handling callback from $name (simulated)…',
              _SsoFlowState.done => 'Signed in via $name (simulated)',
              _SsoFlowState.idle => '',
            },
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: ZapSpacing.xs),
          ZapBadge(
            label: provider?.protocol == _SsoProtocol.saml ? 'SAML 2.0' : 'OAUTH 2.0',
            intent: ZapBadgeIntent.info,
            size: ZapBadgeSize.small,
          ),
          if (state == _SsoFlowState.done) ...[
            const SizedBox(height: ZapSpacing.lg),
            ZapButton.outlined(label: 'Try another provider', fullWidth: true, onPressed: onReset),
          ],
        ],
      ),
    );
  }
}
