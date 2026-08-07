/// Day 224 — Referral: Invite a Friend
///
/// Section B (Days 221-240): personal referral code + link, mock share sheet,
/// and pending/completed referral tracking. Both users earn +10 Protection Score
/// when the friend completes onboarding.
///
/// Tag: 🟡 MOCK-NOW — GET /api/v1/referral/code/ + /stats/
///
/// Route: [AppRoutes.referralInvite] → `/referral-invite`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum ReferralStatus { pending, completed }

class ReferralEntry {
  final String id;
  final String name;
  final String invitedAt;
  final ReferralStatus status;
  final int? bonusPoints;

  const ReferralEntry({
    required this.id,
    required this.name,
    required this.invitedAt,
    required this.status,
    this.bonusPoints,
  });
}

const _kReferralCode = 'ZAP-HRIDYA42';
const _kReferralLink = 'https://zapsafe.app/r/ZAP-HRIDYA42';
const _kShareMessage =
    'Stay safe with ZapSafe — my invite link gives us both +10 Protection Score '
    'when you finish onboarding: $_kReferralLink';

const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kCodeJson = '''{
  "code": "ZAP-HRIDYA42",
  "link": "https://zapsafe.app/r/ZAP-HRIDYA42"
}''';

const _kInitialReferrals = [
  ReferralEntry(
    id: 'r1',
    name: 'Amma',
    invitedAt: '2026-06-10',
    status: ReferralStatus.pending,
  ),
  ReferralEntry(
    id: 'r2',
    name: 'Rahul K.',
    invitedAt: '2026-06-02',
    status: ReferralStatus.completed,
    bonusPoints: 10,
  ),
  ReferralEntry(
    id: 'r3',
    name: 'Neha P.',
    invitedAt: '2026-06-12',
    status: ReferralStatus.pending,
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d224TabProvider = StateProvider<int>((ref) => 0);
final _d224ReferralsProvider =
    StateProvider<List<ReferralEntry>>((ref) => _kInitialReferrals);
final _d224ShareLoadingProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Invite', 'My Referrals', 'API Contract'];

int _invitedCount(List<ReferralEntry> list) => list.length;
int _completedCount(List<ReferralEntry> list) =>
    list.where((r) => r.status == ReferralStatus.completed).length;
int _bonusPoints(List<ReferralEntry> list) =>
    list.fold(0, (sum, r) => sum + (r.bonusPoints ?? 0));

// ── Screen ────────────────────────────────────────────────────────────────────
class Day224ReferralInviteScreen extends ConsumerWidget {
  const Day224ReferralInviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d224TabProvider);
    final bonus = _bonusPoints(ref.watch(_d224ReferralsProvider));

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 224 · Invite Friends'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
                ),
                child: Text(
                  '+$bonus pts',
                  style: const TextStyle(
                    color: ZapColors.safe,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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
            onSelect: (i) => ref.read(_d224TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _InviteTab(),
              1 => const _MyReferralsTab(),
              _ => const _ApiContractTab(),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showMockShareSheet(BuildContext context, WidgetRef ref) async {
  ref.read(_d224ShareLoadingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 400));
  ref.read(_d224ShareLoadingProvider.notifier).state = false;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: ZapColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share invite (mock)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Native share sheet simulation — no external app launch.',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: ZapSpacing.lg),
          _ShareOption(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock share → WhatsApp')),
              );
            },
          ),
          const SizedBox(height: ZapSpacing.sm),
          _ShareOption(
            icon: Icons.sms_rounded,
            label: 'SMS',
            color: ZapColors.info,
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock share → SMS')),
              );
            },
          ),
          const SizedBox(height: ZapSpacing.sm),
          _ShareOption(
            icon: Icons.copy_rounded,
            label: 'Copy link',
            color: ZapColors.warning,
            onTap: () {
              Clipboard.setData(const ClipboardData(text: _kShareMessage));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite message copied')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

// ── Tab 0: Invite ─────────────────────────────────────────────────────────────
class _InviteTab extends ConsumerWidget {
  const _InviteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing = ref.watch(_d224ShareLoadingProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section B Day 4/20 · Settings → Invite Friends',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ZapColors.safe.withOpacity(0.15),
                ZapColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.safe.withOpacity(0.4), width: 2),
          ),
          child: const Column(
            children: [
              Icon(Icons.card_giftcard_rounded,
                  color: ZapColors.safe, size: 40),
              SizedBox(height: ZapSpacing.md),
              Text(
                '+10 Protection Score',
                style: TextStyle(
                  color: ZapColors.safe,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'You and your friend both earn +10 when they complete onboarding.',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        const Text(
          'Your referral code',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  _kReferralCode,
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Semantics(
                label: 'Copy referral code',
                button: true,
                child: IconButton(
                  onPressed: () {
                    Clipboard.setData(
                      const ClipboardData(text: _kReferralCode),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  color: ZapColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Referral link',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            _kReferralLink,
            style: TextStyle(
              color: ZapColors.info,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Share referral invite',
          button: true,
          child: FilledButton.icon(
            onPressed: sharing ? null : () => _showMockShareSheet(context, ref),
            icon: sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded, size: 20),
            label: Text(sharing ? 'Opening share…' : 'Share invite'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.safe,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: _kShareMessage));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Full invite message copied')),
            );
          },
          icon: const Icon(Icons.copy_all_rounded, size: 18),
          label: const Text('Copy invite message'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            foregroundColor: ZapColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Share via $label',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: ZapSpacing.md),
              Text(
                label,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: My Referrals ─────────────────────────────────────────────────────
class _MyReferralsTab extends ConsumerWidget {
  const _MyReferralsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(_d224ReferralsProvider);
    final invited = _invitedCount(referrals);
    final completed = _completedCount(referrals);
    final bonus = _bonusPoints(referrals);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                value: '$invited',
                label: 'Invited',
                color: ZapColors.info,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _StatBox(
                value: '$completed',
                label: 'Completed',
                color: ZapColors.safe,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _StatBox(
                value: '+$bonus',
                label: 'Bonus pts',
                color: ZapColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Referral history',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...referrals.map(
          (r) => _ReferralTile(
            entry: r,
            onSimulateComplete: r.status == ReferralStatus.pending
                ? () {
                    ref.read(_d224ReferralsProvider.notifier).update((list) {
                      return list.map((item) {
                        if (item.id != r.id) return item;
                        return ReferralEntry(
                          id: item.id,
                          name: item.name,
                          invitedAt: item.invitedAt,
                          status: ReferralStatus.completed,
                          bonusPoints: 10,
                        );
                      }).toList();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${r.name} completed onboarding — +10 pts each!',
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.referralRewards),
          icon: const Icon(Icons.emoji_events_rounded, size: 18),
          label: const Text('View rewards & leaderboard (Day 225)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            foregroundColor: ZapColors.warning,
            side: const BorderSide(color: ZapColors.warning),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d224ReferralsProvider.notifier).state =
                _kInitialReferrals;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Referrals reset to demo data')),
            );
          },
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reset demo data'),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  final ReferralEntry entry;
  final VoidCallback? onSimulateComplete;

  const _ReferralTile({
    required this.entry,
    this.onSimulateComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = entry.status == ReferralStatus.completed;
    final color = isComplete ? ZapColors.safe : ZapColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isComplete
              ? ZapColors.safe.withOpacity(0.35)
              : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  entry.name.isNotEmpty ? entry.name[0] : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Invited ${entry.invitedAt}',
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  isComplete ? 'COMPLETED' : 'PENDING',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (isComplete && entry.bonusPoints != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text(
              '+${entry.bonusPoints} Protection Score earned',
              style: const TextStyle(
                color: ZapColors.safe,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (onSimulateComplete != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            TextButton(
              onPressed: onSimulateComplete,
              child: const Text('Simulate friend completed onboarding'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab 2: API Contract ───────────────────────────────────────────────────────
class _ApiContractTab extends ConsumerWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = ref.watch(_d224ReferralsProvider);
    final statsJson = _kJsonEncoder.convert({
      'invited': _invitedCount(referrals),
      'completed': _completedCount(referrals),
      'bonus_points': _bonusPoints(referrals),
    });

    const codeJson = _kCodeJson;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _EndpointCard(
          method: 'GET',
          path: '/api/v1/referral/code/',
          description: 'Personal referral code and shareable deep link.',
          sample: codeJson,
        ),
        const SizedBox(height: ZapSpacing.md),
        _EndpointCard(
          method: 'GET',
          path: '/api/v1/referral/stats/',
          description: 'Aggregate invite counts and earned bonus points.',
          sample: statsJson,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy API contracts',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'GET /api/v1/referral/code/\n$codeJson\n\n'
                      'GET /api/v1/referral/stats/\n$statsJson',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API contracts copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy contracts'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
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
            'Tomorrow: Day 226 — Admin analytics (internal mock dashboard).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EndpointCard extends StatelessWidget {
  final String method;
  final String path;
  final String description;
  final String sample;

  const _EndpointCard({
    required this.method,
    required this.path,
    required this.description,
    required this.sample,
  });

  @override
  Widget build(BuildContext context) {
    final methodColor = method == 'GET' ? ZapColors.info : ZapColors.warning;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method,
                  style: TextStyle(
                    color: methodColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: ZapSpacing.sm),
          SelectableText(
            sample,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            selected ? ZapColors.safe : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
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
