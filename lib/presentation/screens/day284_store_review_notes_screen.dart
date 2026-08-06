/// Day 284 — App Store Review Notes Generator
///
/// Section E (Days 281-300): generate Apple/Google review notes with test
/// account credentials, SOS demo walkthrough, and LP27 blank-screen explanation.
///
/// Tag: 🟢 FRONTEND-ONLY · mock text generator · clipboard export.
///
/// Route: [AppRoutes.storeReviewNotes] → `/store-review-notes`
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
const _kAccent = Color(0xFF0EA5E9);
const _kTabs = ['Apple', 'Google', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kTestEmail = 'reviewer@zapsafe.app';
const _kTestPassword = 'ZapSafe2026!';
const _kTestPin = '123456';
const _kDuressPin = '999999';

enum _ReviewPlatform { apple, google }

String _platformLabel(_ReviewPlatform p) =>
    p == _ReviewPlatform.apple ? 'Apple App Store' : 'Google Play Store';

String _buildReviewNotes({
  required _ReviewPlatform platform,
  required bool includeLp27,
  required bool includeSosSteps,
  required bool includeTestAccount,
}) {
  final buf = StringBuffer();
  final store = _platformLabel(platform);

  buf.writeln('ZapSafe — $store Review Notes');
  buf.writeln('Generated for app review team · mock credentials below');
  buf.writeln();

  if (includeTestAccount) {
    buf.writeln('── TEST ACCOUNT ──');
    buf.writeln('Email: $_kTestEmail');
    buf.writeln('Password: $_kTestPassword');
    buf.writeln('Cancel PIN (normal): $_kTestPin');
    buf.writeln('Duress PIN (silent alert): $_kDuressPin');
    buf.writeln();
    buf.writeln(
      'Pre-seeded: 2 trusted contacts (Tier 1), Journey mode enabled, '
      'location + microphone permissions granted.',
    );
    buf.writeln();
  }

  if (includeSosSteps) {
    buf.writeln('── SOS DEMO STEPS ──');
    buf.writeln('1. Sign in with the test account above.');
    buf.writeln('2. From Home, long-press the SOS ring button for 2 seconds.');
    buf.writeln('3. ALERT_PENDING opens — enter cancel PIN $_kTestPin to dismiss.');
    buf.writeln(
      '4. To test live SOS: long-press again, then enter duress PIN $_kDuressPin '
      '(contacts alerted; UI stays discreet).',
    );
    buf.writeln('5. Evidence vault (Day 82) stores encrypted audio + GPS trail.');
    buf.writeln();
    if (platform == _ReviewPlatform.apple) {
      buf.writeln(
        'Background modes: location updates + audio recording during active SOS only.',
      );
    } else {
      buf.writeln(
        'Foreground service: location + microphone during active SOS session only.',
      );
    }
    buf.writeln();
  }

  if (includeLp27) {
    buf.writeln('── LP27 BLANK-SCREEN PANIC MODE ──');
    buf.writeln(
      'During an active SOS, the screen intentionally shows NO "SOS", '
      '"Emergency", or ZapSafe branding — an attacker observing the phone '
      'should see only a dark screen with ambiguous coordinates.',
    );
    buf.writeln(
      'This is a safety feature (LP27), not a bug. Biometric prompt uses '
      'neutral copy ("Confirm"). Back button is disabled during alert.',
    );
    buf.writeln(
      'See Days 71 (ALERT_PENDING) and 76 (SOS_ACTIVE) for implementation.',
    );
    buf.writeln();
  }

  buf.writeln('── SUPPORT ──');
  buf.writeln('Contact: support@zapsafe.app');
  buf.writeln('Privacy policy: https://zapsafe.github.io/privacy');

  return buf.toString();
}

Map<String, dynamic> _notesPayload({
  required _ReviewPlatform platform,
  required bool includeLp27,
  required bool includeSosSteps,
  required bool includeTestAccount,
}) =>
    {
      'endpoint': 'POST /api/v1/marketing/store-review-notes/',
      'platform': platform.name,
      'sections': {
        'test_account': includeTestAccount,
        'sos_demo_steps': includeSosSteps,
        'lp27_explanation': includeLp27,
      },
      'test_account': {
        'email': _kTestEmail,
        'password': _kTestPassword,
        'cancel_pin': _kTestPin,
        'duress_pin': _kDuressPin,
      },
      'wire_note': 'Mock generator · paste into App Store Connect / Play Console',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d284TabProvider = StateProvider<int>((ref) => 0);
final _d284PlatformProvider =
    StateProvider<_ReviewPlatform>((ref) => _ReviewPlatform.apple);
final _d284IncludeTestAccountProvider = StateProvider<bool>((ref) => true);
final _d284IncludeSosStepsProvider = StateProvider<bool>((ref) => true);
final _d284IncludeLp27Provider = StateProvider<bool>((ref) => true);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day284StoreReviewNotesScreen extends ConsumerWidget {
  const Day284StoreReviewNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(_d284PlatformProvider);
    final tab = ref.watch(_d284TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 284 · Store Review Notes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  _platformLabel(platform).split(' ').first.toUpperCase(),
                  style: const TextStyle(
                    color: _kAccent,
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
            tab: tab,
            onSelect: (i) => ref.read(_d284TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _NotesTab(platform: _ReviewPlatform.apple),
              1 => const _NotesTab(platform: _ReviewPlatform.google),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab: Apple / Google notes ─────────────────────────────────────────────────
class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.platform});

  final _ReviewPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final includeTest = ref.watch(_d284IncludeTestAccountProvider);
    final includeSos = ref.watch(_d284IncludeSosStepsProvider);
    final includeLp27 = ref.watch(_d284IncludeLp27Provider);
    final notes = _buildReviewNotes(
      platform: platform,
      includeTestAccount: includeTest,
      includeSosSteps: includeSos,
      includeLp27: includeLp27,
    );

    final icon = platform == _ReviewPlatform.apple
        ? Icons.apple_rounded
        : Icons.android_rounded;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _SectionTitle(
          title: _platformLabel(platform),
          subtitle: 'Toggle sections · copy full notes to clipboard',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Test account credentials',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Email, password, cancel + duress PINs',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
                ),
                value: includeTest,
                activeColor: _kAccent,
                onChanged: (v) =>
                    ref.read(_d284IncludeTestAccountProvider.notifier).state =
                        v,
              ),
              const Divider(height: 1, color: ZapColors.border),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'SOS demo walkthrough',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Long-press ring · PIN cancel · duress flow',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
                ),
                value: includeSos,
                activeColor: _kAccent,
                onChanged: (v) =>
                    ref.read(_d284IncludeSosStepsProvider.notifier).state = v,
              ),
              const Divider(height: 1, color: ZapColors.border),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'LP27 blank-screen explanation',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Why SOS UI shows no "SOS" text to observers',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
                ),
                value: includeLp27,
                activeColor: _kAccent,
                onChanged: (v) =>
                    ref.read(_d284IncludeLp27Provider.notifier).state = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Icon(icon, color: _kAccent, size: 20),
            const SizedBox(width: ZapSpacing.sm),
            const Text(
              'Generated notes preview',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
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
            notes,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: notes));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_platformLabel(platform)} notes copied.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy notes'),
                style: FilledButton.styleFrom(backgroundColor: _kAccent),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(_d284IncludeTestAccountProvider.notifier).state = true;
                ref.read(_d284IncludeSosStepsProvider.notifier).state = true;
                ref.read(_d284IncludeLp27Provider.notifier).state = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All sections enabled.')),
                );
              },
              icon: const Icon(Icons.select_all_rounded, size: 16),
              label: const Text('All'),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.security_rounded,
          title: 'LP27 is intentional',
          subtitle:
              'Reviewers may think the blank SOS screen is broken — explain '
              'it protects users from coerced unlock.',
        ),
        const _PolicyRow(
          icon: Icons.pin_rounded,
          title: 'PIN reference card',
          subtitle:
              'Cancel $_kTestPin · Duress $_kDuressPin · shown in test account block.',
        ),
      ],
    );
  }
}

// ── Tab: Info ─────────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _notesPayload(
      platform: ref.watch(_d284PlatformProvider),
      includeTestAccount: ref.watch(_d284IncludeTestAccountProvider),
      includeSosSteps: ref.watch(_d284IncludeSosStepsProvider),
      includeLp27: ref.watch(_d284IncludeLp27Provider),
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'App Store review notes',
          subtitle:
              'Paste into App Store Connect "Notes" or Play Console '
              '"App access" section before submission.',
        ),
        const _PolicyRow(
          icon: Icons.account_circle_rounded,
          title: 'Test account',
          subtitle:
              'Dedicated reviewer login — no real user data. Contacts are mock.',
        ),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'SOS demo path',
          subtitle:
              'Long-press ring (Day 203) → ALERT_PENDING (Day 71) → '
              'SOS_ACTIVE (Day 76) with encrypted evidence.',
        ),
        const _PolicyRow(
          icon: Icons.visibility_off_rounded,
          title: 'LP27 blank-screen',
          subtitle:
              'Active SOS hides branding and emergency labels from anyone '
              'watching the device screen.',
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
              const SnackBar(content: Text('Review notes spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
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
            'Tomorrow: Day 285 — Security Pre-Launch Audit '
            '(OWASP MASVS L2 · Days 181-190 ties).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 283 Storyboard'),
              onPressed: () => context.push(AppRoutes.demoVideoStoryboard),
            ),
            ActionChip(
              label: const Text('Day 71 Alert Pending'),
              onPressed: () => context.push(AppRoutes.alertPending),
            ),
            ActionChip(
              label: const Text('Day 76 SOS Active'),
              onPressed: () => context.push(AppRoutes.sosActive),
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
