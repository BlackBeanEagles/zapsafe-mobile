/// Day 103 — Month 1-2 Translation Coverage
///
/// Shows coverage of the 3 new JSON namespaces (onboarding, permissions, push)
/// across all 15 locales, with a live locale selector and key preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/i18n_providers.dart';
import '../../core/theme/spacing.dart';

class Day103TranslationCoverageScreen extends ConsumerWidget {
  const Day103TranslationCoverageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(i18nProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _HeroBanner(state: state),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                const _StatsRow(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionHeader('New Namespaces — Day 103'),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceCard(
                  icon: Icons.waving_hand_rounded,
                  color: Color(0xFF8B5CF6),
                  namespace: 'onboarding',
                  keyCount: 13,
                  keys: [
                    'step1_title', 'step1_desc', 'step2_title', 'step2_desc',
                    'step3_title', 'step3_desc', 'step4_title', 'step4_desc',
                    'step5_title', 'step5_desc', 'next', 'skip', 'get_started',
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceCard(
                  icon: Icons.lock_open_rounded,
                  color: Color(0xFF06B6D4),
                  namespace: 'permissions',
                  keyCount: 12,
                  keys: [
                    'title', 'subtitle', 'location', 'location_desc',
                    'microphone', 'microphone_desc', 'notification',
                    'notification_desc', 'contacts', 'contacts_desc',
                    'allow', 'deny',
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceCard(
                  icon: Icons.notifications_rounded,
                  color: Color(0xFFF59E0B),
                  namespace: 'push',
                  keyCount: 8,
                  keys: [
                    'sos_title', 'sos_body', 'check_in_title', 'check_in_body',
                    'drill_title', 'drill_body', 'contact_added', 'battery_low',
                  ],
                ),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionHeader('Month 1-2 Screen Checklist'),
                const SizedBox(height: ZapSpacing.sm),
                const _ScreenChecklist(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionHeader('Live Preview'),
                const SizedBox(height: ZapSpacing.sm),
                _LocaleSelector(state: state, ref: ref),
                const SizedBox(height: ZapSpacing.sm),
                _LivePreview(state: state),
                const SizedBox(height: ZapSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(ZapSpacing.md),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3730A3), Color(0xFF1E1B4B)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6D28D9), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D28D9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('DAY 103', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C1D95).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
                  ),
                  child: Text(
                    '${state.lang.flag} ${state.lang.nativeName}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text(
              'Month 1-2\nTranslation Coverage',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              '3 new namespaces · 33 new keys · 16 Month 1-2 screens · 15 languages',
              style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatBox(value: '16', label: 'Screens')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '3', label: 'Namespaces')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '200+', label: 'Keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '15', label: 'Languages')),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF6D28D9),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Namespace Card ───────────────────────────────────────────────────────────

class _NamespaceCard extends StatelessWidget {
  const _NamespaceCard({
    required this.icon,
    required this.color,
    required this.namespace,
    required this.keyCount,
    required this.keys,
  });

  final IconData icon;
  final Color color;
  final String namespace;
  final int keyCount;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(namespace, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('$keyCount keys', style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text('15 langs', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keys.map((k) => _KeyChip(k, color)).toList(),
          ),
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontFamily: 'monospace')),
    );
  }
}

// ─── Screen Checklist ─────────────────────────────────────────────────────────

class _ScreenChecklist extends StatelessWidget {
  const _ScreenChecklist();

  static const _screens = [
    'Login · Phone Entry',
    'OTP Verify',
    'App Permissions',
    'Onboarding Step 1 — Welcome',
    'Onboarding Step 2 — Emergency Contacts',
    'Onboarding Step 3 — Location & Audio',
    'Onboarding Step 4 — Customise Alerts',
    'Onboarding Step 5 — All Set',
    'Phone Capability',
    'Feature Flags',
    'Drills & Schedule',
    'Push Notifications',
    'Push Routing',
    'Device Tier',
    'Auth Foundation',
    'Week 3 Review',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        children: List.generate(_screens.length, (i) {
          final isLast = i == _screens.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.md),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(child: Text(_screens[i], style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13))),
                Text('${i + 1}', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Locale Selector ──────────────────────────────────────────────────────────

class _LocaleSelector extends StatelessWidget {
  const _LocaleSelector({required this.state, required this.ref});
  final I18nState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kSupportedLanguages.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZapSpacing.sm),
        itemBuilder: (_, i) {
          final lang = kSupportedLanguages[i];
          final selected = lang.code == state.selectedCode;
          return GestureDetector(
            onTap: () => ref.read(i18nProvider.notifier).select(lang.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF6D28D9) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? const Color(0xFF7C3AED) : const Color(0xFF2A2A2A),
                ),
              ),
              child: Text(
                '${lang.flag} ${lang.code.toUpperCase()}',
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Live Preview ─────────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final coverage = kCoverageTranslations[state.selectedCode] ?? kCoverageTranslations['en']!;
    final isRtl = state.isRtl;
    final dir = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: dir,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(state.lang.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  state.lang.nativeName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (isRtl) ...[
                  const SizedBox(width: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('RTL', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            const Divider(color: Color(0xFF1F1F1F), height: 24),
            ...coverage.entries.map((e) => _PreviewRow(key: ValueKey(e.key), keyName: e.key, value: e.value)),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({super.key, required this.keyName, required this.value});
  final String keyName;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              keyName,
              style: const TextStyle(color: Color(0xFF6D28D9), fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
