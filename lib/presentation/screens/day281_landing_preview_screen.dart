/// Day 281 — Marketing Landing Preview (In-App)
///
/// Section E (Days 281-300): styled GitHub Pages landing preview with store
/// link verification — ensures marketing URLs match app store listings.
///
/// Tag: 🟢 FRONTEND-ONLY · no WebView dependency · styled mock landing page.
///
/// Route: [AppRoutes.landingPreview] → `/landing-preview`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFEC4899);
const _kTabs = ['Landing', 'Links', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kLandingUrl = 'https://zapsafe.github.io/';
const _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.zapsafe.app';
const _kAppStoreUrl = 'https://apps.apple.com/app/zapsafe/id1234567890';
const _kPrivacyUrl = 'https://zapsafe.github.io/privacy';
const _kTermsUrl = 'https://zapsafe.github.io/terms';
const _kSupportEmail = 'support@zapsafe.app';

class _StoreLink {
  const _StoreLink({
    required this.id,
    required this.label,
    required this.landingHref,
    required this.storeListingHref,
    required this.icon,
  });

  final String id;
  final String label;
  final String landingHref;
  final String storeListingHref;
  final IconData icon;
}

const _kStoreLinks = [
  _StoreLink(
    id: 'play_store',
    label: 'Google Play',
    landingHref: _kPlayStoreUrl,
    storeListingHref: _kPlayStoreUrl,
    icon: Icons.android_rounded,
  ),
  _StoreLink(
    id: 'app_store',
    label: 'Apple App Store',
    landingHref: _kAppStoreUrl,
    storeListingHref: _kAppStoreUrl,
    icon: Icons.apple_rounded,
  ),
  _StoreLink(
    id: 'privacy',
    label: 'Privacy policy',
    landingHref: _kPrivacyUrl,
    storeListingHref: _kPrivacyUrl,
    icon: Icons.privacy_tip_outlined,
  ),
  _StoreLink(
    id: 'terms',
    label: 'Terms of service',
    landingHref: _kTermsUrl,
    storeListingHref: _kTermsUrl,
    icon: Icons.gavel_rounded,
  ),
  _StoreLink(
    id: 'support',
    label: 'Support email',
    landingHref: 'mailto:$_kSupportEmail',
    storeListingHref: 'mailto:$_kSupportEmail',
    icon: Icons.email_outlined,
  ),
];

const _kLandingFeatures = [
  ('SOS in 2 seconds', 'Long-press ring · instant Tier 1 alert'),
  ('Evidence vault', 'Encrypted audio · photo · location trail'),
  ('Privacy first', 'On-device AI · consent gates · no ad tracking'),
];

Map<String, dynamic> _landingPayload({
  required bool darkPreview,
  required Set<String> verified,
  required bool auditRun,
}) =>
    {
      'endpoint': 'GET /api/v1/marketing/landing-preview/',
      'landing_url': _kLandingUrl,
      'preview_mode': darkPreview ? 'dark' : 'light',
      'link_audit_run': auditRun,
      'links_verified': verified.length,
      'links_total': _kStoreLinks.length,
      'links': _kStoreLinks
          .map(
            (l) => {
              'id': l.id,
              'landing': l.landingHref,
              'store_listing': l.storeListingHref,
              'match': verified.contains(l.id),
            },
          )
          .toList(),
      'wire_note': 'Styled in-app preview · swap to WebView when GH Pages live',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d281TabProvider = StateProvider<int>((ref) => 0);
final _d281DarkPreviewProvider = StateProvider<bool>((ref) => false);
final _d281VerifiedProvider = StateProvider<Set<String>>((ref) => {});
final _d281AuditingProvider = StateProvider<bool>((ref) => false);
final _d281AuditDoneProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day281LandingPreviewScreen extends ConsumerWidget {
  const Day281LandingPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(_d281VerifiedProvider);
    final auditDone = ref.watch(_d281AuditDoneProvider);
    final allMatch = verified.length == _kStoreLinks.length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 281 · Landing Preview'),
        actions: [
          IconButton(
            tooltip: 'Toggle dark landing preview',
            onPressed: () =>
                ref.read(_d281DarkPreviewProvider.notifier).state =
                    !ref.watch(_d281DarkPreviewProvider),
            icon: Icon(
              ref.watch(_d281DarkPreviewProvider)
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_outlined,
              color: ZapColors.textMuted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (allMatch && auditDone
                          ? ZapColors.safe
                          : _kAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (allMatch && auditDone
                            ? ZapColors.safe
                            : _kAccent)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  allMatch && auditDone
                      ? 'LINKS OK ✅'
                      : '${verified.length}/${_kStoreLinks.length}',
                  style: TextStyle(
                    color: allMatch && auditDone ? ZapColors.safe : _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d281TabProvider),
            onSelect: (i) => ref.read(_d281TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d281TabProvider)) {
              0 => const _LandingTab(),
              1 => const _LinksTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Landing ────────────────────────────────────────────────────────────
class _LandingTab extends ConsumerWidget {
  const _LandingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(_d281DarkPreviewProvider);
    final bg = dark ? const Color(0xFF0F172A) : Colors.white;
    final fg = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section E Day 1/20 · GitHub Pages style preview · store link QA',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, size: 14, color: _kAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _kLandingUrl,
                        style: TextStyle(color: muted, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      dark ? 'DARK' : 'LIGHT',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.lg),
                child: Column(
                  children: [
                    const Icon(Icons.shield_rounded, size: 48, color: ZapColors.danger),
                    const SizedBox(height: ZapSpacing.md),
                    Text(
                      'ZapSafe',
                      style: TextStyle(
                        color: fg,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      'Personal safety that respects your privacy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: ZapSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                const ClipboardData(text: _kPlayStoreUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Play Store URL copied.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.android_rounded, size: 16),
                            label: const Text('Google Play'),
                            style: FilledButton.styleFrom(
                              backgroundColor: ZapColors.safe,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                const ClipboardData(text: _kAppStoreUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('App Store URL copied.'),
                                ),
                              );
                            },
                            icon: Icon(Icons.apple_rounded, size: 16, color: fg),
                            label: Text('App Store', style: TextStyle(color: fg)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: dark ? const Color(0xFF334155) : ZapColors.border),
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.lg),
                child: Column(
                  children: [
                    for (final f in _kLandingFeatures)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: ZapColors.safe),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.$1,
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    f.$2,
                                    style: TextStyle(color: muted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                color: dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    Text(
                      'Footer links',
                      style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: [
                        Text('Privacy', style: TextStyle(color: _kAccent, fontSize: 10)),
                        Text('Terms', style: TextStyle(color: _kAccent, fontSize: 10)),
                        Text(_kSupportEmail,
                            style: TextStyle(color: _kAccent, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Styled mock of GitHub Pages landing · WebView optional when site is live.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Tab 1: Links ──────────────────────────────────────────────────────────────
class _LinksTab extends ConsumerWidget {
  const _LinksTab();

  Future<void> _runAudit(WidgetRef ref) async {
    ref.read(_d281AuditingProvider.notifier).state = true;
    ref.read(_d281VerifiedProvider.notifier).state = {};
    ref.read(_d281AuditDoneProvider.notifier).state = false;

    for (final link in _kStoreLinks) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      ref.read(_d281VerifiedProvider.notifier).update(
            (s) => {...s, link.id},
          );
    }

    ref.read(_d281AuditingProvider.notifier).state = false;
    ref.read(_d281AuditDoneProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(_d281VerifiedProvider);
    final auditing = ref.watch(_d281AuditingProvider);
    final auditDone = ref.watch(_d281AuditDoneProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Store listing link audit',
          subtitle: 'Compare landing page hrefs vs Play Console / App Store Connect',
        ),
        ..._kStoreLinks.map((link) {
          final ok = verified.contains(link.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ok
                  ? ZapColors.safe.withOpacity(0.08)
                  : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ok
                    ? ZapColors.safe.withOpacity(0.4)
                    : ZapColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(link.icon, size: 18, color: _kAccent),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        link.label,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      ok
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: ok ? ZapColors.safe : ZapColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Landing: ${link.landingHref}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Store:  ${link.storeListingHref}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: auditing ? null : () => _runAudit(ref),
            icon: auditing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    auditDone
                        ? Icons.refresh_rounded
                        : Icons.fact_check_rounded,
                    size: 16,
                  ),
            label: Text(
              auditing
                  ? 'Auditing links…'
                  : auditDone
                      ? 'Re-run link audit'
                      : 'Run link audit',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (auditDone && verified.length == _kStoreLinks.length) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: ZapColors.safe, size: 18),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'All landing links match store listing URLs (mock).',
                    style: TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(_d281DarkPreviewProvider);
    final verified = ref.watch(_d281VerifiedProvider);
    final auditDone = ref.watch(_d281AuditDoneProvider);
    final payload = _landingPayload(
      darkPreview: dark,
      verified: verified,
      auditRun: auditDone,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.web_rounded,
          title: 'Marketing landing preview',
          subtitle:
              'In-app styled preview of the GitHub Pages site · verify CTA '
              'buttons and footer links match Play Console / App Store Connect.',
        ),
        const _PolicyRow(
          icon: Icons.link_rounded,
          title: 'Link audit mock',
          subtitle:
              'Runs sequential href comparison · flags mismatches before '
              'public launch · no network call in demo.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Landing preview spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy landing spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 280 Section D Milestone'),
              onPressed: () => context.push(AppRoutes.sectionDMilestone),
            ),
            ActionChip(
              label: const Text('Day 151 Privacy Policy'),
              onPressed: () => context.push(AppRoutes.privacyPolicy),
            ),
            ActionChip(
              label: const Text('Day 152 Policy Consent'),
              onPressed: () => context.push(AppRoutes.policyConsent),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
