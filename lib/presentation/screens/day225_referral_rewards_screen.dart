/// Day 225 — Referral Rewards & Leaderboard Tie-In
///
/// Section B (Days 221-240): earned referral bonuses, full history ledger,
/// and tie-in to Protection Score / gamification leaderboard (Day 59).
///
/// Tag: 🟡 MOCK-NOW — GET rewards + history; links Day 224 invite flow.
///
/// Route: [AppRoutes.referralRewards] → `/referral-rewards`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum RewardEntryType { referralBonus, friendBonus, milestone }

class RewardLedgerEntry {
  final String id;
  final String title;
  final String subtitle;
  final int points;
  final String date;
  final RewardEntryType type;

  const RewardLedgerEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.date,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'points': points,
        'date': date,
        'type': type.name,
      };
}

class LeaderboardRow {
  final int rank;
  final String name;
  final int score;
  final bool isYou;

  const LeaderboardRow({
    required this.rank,
    required this.name,
    required this.score,
    this.isYou = false,
  });
}

const _kBaseScore = 78;
const _kReferralBonus = 10;
const _kAfterScore = _kBaseScore + _kReferralBonus;
const _kTotalBonus = 10;

const _kLedger = [
  RewardLedgerEntry(
    id: 'rw1',
    title: 'Rahul K. completed onboarding',
    subtitle: 'Referral bonus · both users +10',
    points: 10,
    date: '2026-06-03',
    type: RewardEntryType.referralBonus,
  ),
];

const _kReferralHistory = [
  ('Rahul K.', '2026-06-02', 'Completed', '+10 pts', true),
  ('Amma', '2026-06-10', 'Pending', '—', false),
  ('Neha P.', '2026-06-12', 'Pending', '—', false),
];

const _kLeaderboard = [
  LeaderboardRow(rank: 140, name: 'Ananya R.', score: 94),
  LeaderboardRow(rank: 141, name: 'Dev P.', score: 91),
  LeaderboardRow(rank: 142, name: 'You (Priya)', score: 88, isYou: true),
  LeaderboardRow(rank: 143, name: 'Sneha M.', score: 87),
  LeaderboardRow(rank: 144, name: 'Karan J.', score: 85),
];

const _kRewardsJson = '''{
  "total_bonus": 10,
  "protection_score_before": 78,
  "protection_score_after": 88,
  "entries": [
    {
      "id": "rw1",
      "title": "Rahul K. completed onboarding",
      "points": 10,
      "date": "2026-06-03",
      "type": "referralBonus"
    }
  ]
}''';

const _kHistoryJson = '''{
  "invited": 3,
  "completed": 1,
  "pending": 2,
  "bonus_points": 10
}''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d225TabProvider = StateProvider<int>((ref) => 0);

const _kTabs = ['Rewards', 'History', 'Leaderboard'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day225ReferralRewardsScreen extends ConsumerWidget {
  const Day225ReferralRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d225TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 225 · Referral Rewards'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
                ),
                child: const Text(
                  '+10 earned',
                  style: TextStyle(
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
            onSelect: (i) => ref.read(_d225TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _RewardsTab(),
              1 => const _HistoryTab(),
              _ => const _LeaderboardTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Rewards ────────────────────────────────────────────────────────────
class _RewardsTab extends StatelessWidget {
  const _RewardsTab();

  @override
  Widget build(BuildContext context) {
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
            '🟡 MOCK-NOW · Section B Day 5/20 · ties to Day 59 Protection Score',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.card_giftcard_rounded, size: 16),
              label: const Text('Day 224 Invite'),
              onPressed: () => context.push(AppRoutes.referralInvite),
            ),
            ActionChip(
              avatar: const Icon(Icons.shield_rounded, size: 16),
              label: const Text('Day 59 Score'),
              onPressed: () => context.push(AppRoutes.protectionScore),
            ),
          ],
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
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border:
                Border.all(color: ZapColors.safe.withOpacity(0.45), width: 2),
          ),
          child: const Column(
            children: [
              Text(
                '+$_kTotalBonus',
                style: TextStyle(
                  color: ZapColors.safe,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Referral bonus points earned',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ZapSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ScorePill(label: 'Before', value: '$_kBaseScore'),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: ZapSpacing.md),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: ZapColors.textMuted, size: 18),
                  ),
                  _ScorePill(
                    label: 'After',
                    value: '$_kAfterScore',
                    highlight: true,
                  ),
                ],
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Protection Score includes referral bonuses in gamification ring',
                style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        const Text(
          'Bonus ledger',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kLedger.map((e) => _LedgerTile(entry: e)),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Open protection score screen',
          button: true,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.protectionScore),
            icon: const Icon(Icons.leaderboard_rounded, size: 18),
            label: const Text('View Protection Score (Day 59)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.info,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ScorePill({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? ZapColors.safe : ZapColors.textSecondary;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final RewardLedgerEntry entry;

  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.12),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: const Icon(Icons.stars_rounded, color: ZapColors.safe),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${entry.subtitle} · ${entry.date}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${entry.points}',
            style: const TextStyle(
              color: ZapColors.safe,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: History ────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Row(
          children: [
            Expanded(
              child: _MiniStat(
                  value: '3', label: 'Invited', color: ZapColors.info),
            ),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _MiniStat(
                value: '1',
                label: 'Completed',
                color: ZapColors.safe,
              ),
            ),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: _MiniStat(
                value: '2',
                label: 'Pending',
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
        ..._kReferralHistory.map((row) {
          final (name, date, status, bonus, completed) = row;
          final color = completed ? ZapColors.safe : ZapColors.warning;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: completed
                    ? ZapColors.safe.withOpacity(0.35)
                    : ZapColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Invited $date',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      bonus,
                      style: TextStyle(
                        color: completed ? ZapColors.safe : ZapColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.referralInvite),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Invite more friends (Day 224)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            foregroundColor: ZapColors.textPrimary,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgElevated,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            _kHistoryJson,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
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
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
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

// ── Tab 2: Leaderboard ────────────────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Community leaderboard (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        const Text(
          'Referral bonuses feed into your Protection Score rank.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kLeaderboard.map((row) => _LeaderboardTile(row: row)),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Your rank #142 moved up +3 after Rahul\'s referral bonus. '
            'Full score breakdown lives on Day 59 Protection Score screen.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Open gamification leaderboard',
          button: true,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.protectionScore),
            icon: const Icon(Icons.emoji_events_rounded, size: 18),
            label: const Text('Open Protection Score leaderboard'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.warning,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'GET /api/v1/referral/rewards/',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            _kRewardsJson,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy rewards API sample',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: 'GET /api/v1/referral/rewards/\n$_kRewardsJson',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API sample copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy API sample'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 227 — Notification history polish v2.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardRow row;

  const _LeaderboardTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final highlight = row.isYou;
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color:
            highlight ? ZapColors.warning.withOpacity(0.08) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: highlight
              ? ZapColors.warning.withOpacity(0.45)
              : ZapColors.border,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${row.rank}',
              style: TextStyle(
                color: highlight ? ZapColors.warning : ZapColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.name,
              style: TextStyle(
                color:
                    highlight ? ZapColors.textPrimary : ZapColors.textSecondary,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${row.score} pts',
            style: TextStyle(
              color: highlight ? ZapColors.warning : ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
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
                        color: selected ? ZapColors.safe : Colors.transparent,
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
