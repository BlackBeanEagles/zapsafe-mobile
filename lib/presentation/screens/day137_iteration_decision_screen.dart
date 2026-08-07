/// Day 137 — Feedback Analysis & Iteration Decision
///
/// Second half of the Days 136-137 feedback cycle.
/// Day 136 collected quantitative data (survey, Sentry, retention).
/// Day 137 goes deeper:
///   1. Qualitative feedback — read & categorise tester comments
///   2. DAU trend — are daily active users growing post-fix?
///   3. Feature usage — which screens are testers actually using?
///   4. Iteration decision gate — what goes to Days 138-139, what's done?
///
/// Output: signed-off list of remaining P0/P1 items for Days 138-139,
/// and confirmation that everything else is ready for v0.5-beta-final.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _feedFilterProvider     = StateProvider<_FeedFilter>((ref) => _FeedFilter.all);
final _decisionProvider       = StateProvider<Map<int, _Decision>>((ref) => {});
final _gatePassedProvider     = StateProvider<bool>((ref) => false);

enum _FeedFilter { all, positive, negative, request }
enum _Decision   { fix, defer, wontFix }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Comment {
  final String name;
  final String initials;
  final Color  avatarColor;
  final String device;
  final _FeedFilter sentiment;
  final int    rating;
  final String text;
  final String tag;
  final Color  tagColor;
  const _Comment({
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.device,
    required this.sentiment,
    required this.rating,
    required this.text,
    required this.tag,
    required this.tagColor,
  });
}

const _kComments = [
  _Comment(
    name: 'Priya Kumar', initials: 'PK',
    avatarColor: Color(0xFF10B981),
    device: 'iPhone 14 · iOS 17',
    sentiment: _FeedFilter.positive,
    rating: 5,
    text: 'App runs perfectly now! No crashes in 2 weeks. '
        'The battery fix is incredible — was draining 25% per hour, '
        'now barely 6%. Five stars.',
    tag: 'Performance',
    tagColor: Color(0xFF8B5CF6),
  ),
  _Comment(
    name: 'Arjun Singh', initials: 'AS',
    avatarColor: Color(0xFF3B82F6),
    device: 'Samsung S23 · Android 13',
    sentiment: _FeedFilter.positive,
    rating: 5,
    text: 'Samsung notification delay is fixed! Used to wait 40+ seconds. '
        'Now it\'s instant. The new onboarding also took me < 2 min. '
        'Great work.',
    tag: 'Notifications',
    tagColor: Color(0xFF3B82F6),
  ),
  _Comment(
    name: 'Meera Patel', initials: 'MP',
    avatarColor: Color(0xFF8B5CF6),
    device: 'Xiaomi Redmi 9 · Android 12',
    sentiment: _FeedFilter.positive,
    rating: 4,
    text: 'No more crashes on my budget phone. The LITE tier notice '
        'told me detection is limited but at least it doesn\'t crash anymore. '
        'Would love full detection on my phone.',
    tag: 'Low-RAM',
    tagColor: Color(0xFFF97316),
  ),
  _Comment(
    name: 'Rahul Sharma', initials: 'RS',
    avatarColor: Color(0xFFF59E0B),
    device: 'Pixel 7 · Android 14',
    sentiment: _FeedFilter.negative,
    rating: 3,
    text: 'App still shows a brief white flash before the dark theme loads. '
        'Minor but annoying. Also the evidence vault list takes 1-2 seconds '
        'to load on first open.',
    tag: 'UI Polish',
    tagColor: Color(0xFF4B5563),
  ),
  _Comment(
    name: 'Anita Desai', initials: 'AD',
    avatarColor: Color(0xFFF97316),
    device: 'OnePlus 11 · Android 13',
    sentiment: _FeedFilter.request,
    rating: 4,
    text: 'Love the app. One request: can you add a widget for the '
        'home screen? A quick SOS button on the lock screen would '
        'be life-saving. Also want wearable support.',
    tag: 'Feature Request',
    tagColor: Color(0xFF3B82F6),
  ),
  _Comment(
    name: 'Sonia Kapoor', initials: 'SK',
    avatarColor: Color(0xFFEF4444),
    device: 'Huawei P30 · EMUI 12',
    sentiment: _FeedFilter.positive,
    rating: 4,
    text: 'The AutoStart prompt fixed my Huawei notification issue. '
        'Followed the steps and now alerts arrive instantly. '
        'Thank you for detecting the issue automatically!',
    tag: 'Brand Fix',
    tagColor: Color(0xFFF59E0B),
  ),
  _Comment(
    name: 'Vikram Rao', initials: 'VR',
    avatarColor: Color(0xFF10B981),
    device: 'iPhone SE · iOS 16',
    sentiment: _FeedFilter.negative,
    rating: 3,
    text: 'The explanation card after SOS is great but appears too briefly. '
        'I almost missed it. Could you keep it on screen until I dismiss it? '
        'Also the text is small on SE.',
    tag: 'UX Polish',
    tagColor: Color(0xFF4B5563),
  ),
  _Comment(
    name: 'Neha Gupta', initials: 'NG',
    avatarColor: Color(0xFF8B5CF6),
    device: 'Samsung A53 · Android 13',
    sentiment: _FeedFilter.request,
    rating: 5,
    text: 'Can you add a "Panic mode" where the app looks like a calculator '
        'to hide it from an abuser? My friend who\'s in a DV situation '
        'really needs this.',
    tag: 'Safety Feature',
    tagColor: Color(0xFFEF4444),
  ),
];

// DAU data - 14 days post v0.5-beta-2
const _kDauBefore = [
  312, 298, 287, 271, 265, 258, 252, 248, 244, 240, 237, 234, 231, 228
];
const _kDauAfter = [
  612, 598, 589, 576, 568, 561, 558, 554, 551, 548, 546, 543, 541, 539
];

// Feature usage (screen opens per 1000 sessions)
const _kFeatureUsage = [
  ('Dashboard',       892, Color(0xFF10B981)),
  ('SOS Active',      234, Color(0xFFEF4444)),
  ('Evidence Vault',  187, Color(0xFF8B5CF6)),
  ('Trusted Circle',  156, Color(0xFF3B82F6)),
  ('Settings',        143, Color(0xFF9CA3AF)),
  ('Safety Map',      112, Color(0xFFF59E0B)),
  ('Live Chat',        89, Color(0xFFF97316)),
  ('Drill Mode',       67, Color(0xFF10B981)),
  ('Gamification',     54, Color(0xFF8B5CF6)),
  ('Analytics',        41, Color(0xFF3B82F6)),
];

class _IterationItem {
  final String title;
  final String source;
  final String priority;
  final Color  priorityColor;
  final String effort;
  final String impact;
  const _IterationItem({
    required this.title,
    required this.source,
    required this.priority,
    required this.priorityColor,
    required this.effort,
    required this.impact,
  });
}

const _kIterationItems = [
  _IterationItem(
    title: 'SOS explanation card — keep on screen until dismissed',
    source: 'Vikram R. + 4 others',
    priority: 'P1', priorityColor: Color(0xFFF97316),
    effort: '2h', impact: 'Prevents user confusion on false alarm',
  ),
  _IterationItem(
    title: 'White flash on app launch (theme load delay)',
    source: 'Rahul S. + 3 others',
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    effort: '1h', impact: 'Polish — removes jarring flash',
  ),
  _IterationItem(
    title: 'Evidence vault list — 1-2s load on first open',
    source: 'Rahul S.',
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    effort: '3h', impact: 'Perceived performance improvement',
  ),
  _IterationItem(
    title: 'SOS explanation text too small on iPhone SE',
    source: 'Vikram R.',
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    effort: '30m', impact: 'Accessibility improvement',
  ),
];

const _kDeferredItems = [
  'Lock screen / home screen widget (requested by 47 testers)',
  'Wearable support (requested by 31 testers)',
  '"Calculator disguise" panic mode (safety use case — v9.1 roadmap)',
  'Scheduled quiet hours (requested by 28 testers)',
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day137IterationDecisionScreen extends ConsumerWidget {
  const Day137IterationDecisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 137 · Iteration Decision'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _FeedbackFeedTab(),
            if (tab == 1) const _DauFeatureTab(),
            if (tab == 2) const _DecisionTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1220), Color(0xFF07090F), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 137', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Iteration decision', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Feedback Analysis &\nIteration Decision',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '612 survey responses, 8 tester comments analysed, '
            'DAU up 96% post-fix. Now deciding: what 4 items '
            'go to Days 138-139, and what is DONE forever.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('612',  'Responses',      Color(0xFF3B82F6)),
            _HStat('+96%', 'DAU growth',     Color(0xFF10B981)),
            _HStat('4',    'Items to fix',   Color(0xFFF97316)),
            _HStat('140',  'Final tag day',  Color(0xFF8B5CF6)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.chat_bubble_rounded,    Color(0xFF3B82F6), 'Comments'),
      (Icons.trending_up_rounded,    Color(0xFF10B981), 'DAU & Usage'),
      (Icons.check_box_rounded,      Color(0xFF8B5CF6), 'Decision'),
    ];
    return Row(
      children: List.generate(3, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Feedback Feed Tab ──────────────────────────────────────────────────────────
class _FeedbackFeedTab extends ConsumerWidget {
  const _FeedbackFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_feedFilterProvider);
    final visible = _kComments.where((c) {
      if (filter == _FeedFilter.all) return true;
      return c.sentiment == filter;
    }).toList();

    // Sentiment counts
    final pos = _kComments.where((c) => c.sentiment == _FeedFilter.positive).length;
    final neg = _kComments.where((c) => c.sentiment == _FeedFilter.negative).length;
    final req = _kComments.where((c) => c.sentiment == _FeedFilter.request).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sentiment summary chips
        Row(children: [
          _filterChip(_FeedFilter.all,      'All (${_kComments.length})',
              const Color(0xFF9CA3AF), filter, ref),
          const SizedBox(width: ZapSpacing.sm),
          _filterChip(_FeedFilter.positive, '✅ Positive ($pos)',
              const Color(0xFF10B981), filter, ref),
          const SizedBox(width: ZapSpacing.sm),
          _filterChip(_FeedFilter.negative, '⚠️ Issues ($neg)',
              const Color(0xFFEF4444), filter, ref),
          const SizedBox(width: ZapSpacing.sm),
          _filterChip(_FeedFilter.request,  '💡 Requests ($req)',
              const Color(0xFF3B82F6), filter, ref),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Sentiment bar
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$pos positive',
                    style: const TextStyle(
                        color: Color(0xFF10B981), fontSize: 11,
                        fontWeight: FontWeight.w700)),
                Text('$neg issues',
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 11,
                        fontWeight: FontWeight.w700)),
                Text('$req requests',
                    style: const TextStyle(
                        color: Color(0xFF3B82F6), fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(children: [
                Expanded(
                  flex: pos,
                  child: Container(
                      height: 8,
                      color: const Color(0xFF10B981).withOpacity(0.7)),
                ),
                Expanded(
                  flex: neg,
                  child: Container(
                      height: 8,
                      color: const Color(0xFFEF4444).withOpacity(0.7)),
                ),
                Expanded(
                  flex: req,
                  child: Container(
                      height: 8,
                      color: const Color(0xFF3B82F6).withOpacity(0.7)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Comment cards
        const _SectionLabel('TESTER COMMENTS'),
        const SizedBox(height: ZapSpacing.md),
        ...visible.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _CommentCard(comment: c),
            )),

        if (visible.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(ZapSpacing.xl),
              child: Text('No comments match this filter',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(
    _FeedFilter value,
    String label,
    Color color,
    _FeedFilter current,
    WidgetRef ref,
  ) {
    final isActive = current == value;
    return GestureDetector(
      onTap: () => ref.read(_feedFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final _Comment comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final c = comment;
    final sentimentColor = c.sentiment == _FeedFilter.positive
        ? const Color(0xFF10B981)
        : c.sentiment == _FeedFilter.negative
            ? const Color(0xFFEF4444)
            : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: sentimentColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: sentimentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: c.avatarColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(c.initials,
                    style: TextStyle(
                        color: c.avatarColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text(c.device,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                ],
              ),
            ),
            // Stars
            Row(
              children: List.generate(5, (i) => Icon(
                    i < c.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i < c.rating
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF2A2A2A),
                    size: 14,
                  )),
            ),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          // Comment text
          Text(c.text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
          const SizedBox(height: ZapSpacing.sm),
          // Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.tagColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(c.tag,
                style: TextStyle(
                    color: c.tagColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── DAU & Feature Tab ──────────────────────────────────────────────────────────
class _DauFeatureTab extends StatelessWidget {
  const _DauFeatureTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // DAU chart
        const _SectionLabel('DAILY ACTIVE USERS  ·  14 DAYS POST-RELEASE'),
        const SizedBox(height: ZapSpacing.md),
        const _DauChart(),
        const SizedBox(height: ZapSpacing.xl),

        // Feature usage
        const _SectionLabel('FEATURE USAGE  ·  OPENS PER 1,000 SESSIONS'),
        const SizedBox(height: ZapSpacing.md),
        const _FeatureUsageChart(),
        const SizedBox(height: ZapSpacing.lg),

        // Insights
        const _SectionLabel('KEY INSIGHTS'),
        const SizedBox(height: ZapSpacing.md),
        const _InsightsCard(),
      ],
    );
  }
}

class _DauChart extends StatelessWidget {
  const _DauChart();

  @override
  Widget build(BuildContext context) {
    const maxVal  = 700.0;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Total header
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DAU Day 14',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
              Row(children: [
                Text('${_kDauAfter.last}',
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(width: ZapSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('+96% vs before',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
          // Legend
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _dLegend(const Color(0xFFEF4444).withOpacity(0.4), 'Before'),
            const SizedBox(height: ZapSpacing.xs),
            _dLegend(const Color(0xFF10B981), 'After v0.5-beta-2'),
          ]),
        ]),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(14, (i) {
              final before = _kDauBefore[i].toDouble();
              final after  = _kDauAfter[i].toDouble();
              final hB = (before / maxVal * 70).clamp(2.0, 70.0);
              final hA = (after  / maxVal * 70).clamp(2.0, 70.0);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        height: hB,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2)),
                        ),
                      ),
                      Container(
                        height: hA,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.75),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Day 1', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
            Text('Day 7', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
            Text('Day 14', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
          ],
        ),
      ]),
    );
  }

  Widget _dLegend(Color color, String label) => Row(children: [
        Container(
            width: 12, height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: ZapSpacing.xs),
        Text(label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
      ]);
}

class _FeatureUsageChart extends StatelessWidget {
  const _FeatureUsageChart();

  @override
  Widget build(BuildContext context) {
    final maxVal = _kFeatureUsage.first.$2.toDouble();
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _kFeatureUsage.asMap().entries.map((e) {
          final i = e.key;
          final (name, count, color) = e.value;
          final isLast = i == _kFeatureUsage.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
              child: Row(children: [
                SizedBox(
                  width: 110,
                  child: Text(name,
                      style: const TextStyle(
                          color: Color(0xFFD1D5DB), fontSize: 11)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: count / maxVal,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                SizedBox(
                  width: 32,
                  child: Text('$count',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.end),
                ),
              ]),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard();

  static const _insights = [
    (Icons.trending_up_rounded,   Color(0xFF10B981),
        'DAU up 96%',
        'Double the users engaging daily — fixes drove re-engagement'),
    (Icons.shield_rounded,        Color(0xFFEF4444),
        'SOS Active used 234/1000',
        'High usage confirms safety features are core — polish matters'),
    (Icons.lock_rounded,          Color(0xFF8B5CF6),
        'Evidence vault #3 feature',
        'Users trust the vault — consider faster load time (P2 fix)'),
    (Icons.gamepad_rounded,       Color(0xFF4B5563),
        'Gamification low at 54',
        'Badges/leaderboard underused — may need more visibility'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _insights.asMap().entries.map((e) {
          final i = e.key;
          final (icon, color, title, desc) = e.value;
          final isLast = i == _insights.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Text(desc,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Decision Tab ───────────────────────────────────────────────────────────────
class _DecisionTab extends ConsumerWidget {
  const _DecisionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisions  = ref.watch(_decisionProvider);
    final gatePassed = ref.watch(_gatePassedProvider);
    final allDecided = decisions.length == _kIterationItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.check_box_rounded,
          color: const Color(0xFF8B5CF6),
          text: 'Based on 612 survey responses + Sentry data, '
              '4 items need attention before Day 140 tag. '
              'Assign each item: Fix in Days 138-139 / Defer / Won\'t fix.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Items to decide
        const _SectionLabel('ITEMS TO DECIDE  ·  TAP TO ASSIGN'),
        const SizedBox(height: ZapSpacing.md),
        ..._kIterationItems.asMap().entries.map((e) {
          final i    = e.key;
          final item = e.value;
          final dec  = decisions[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _DecisionCard(
              index: i,
              item: item,
              decision: dec,
              onDecide: (d) {
                final updated = Map<int, _Decision>.from(
                    ref.read(_decisionProvider));
                updated[i] = d;
                ref.read(_decisionProvider.notifier).state = updated;
              },
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.xl),

        // Deferred items
        const _SectionLabel('DEFERRED TO FUTURE RELEASES'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kDeferredItems.asMap().entries.map((e) {
              final i     = e.key;
              final text  = e.value;
              final isLast= i == _kDeferredItems.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: Color(0xFF4B5563), size: 14),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(text,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Decision summary + gate
        const _SectionLabel('DECISION SUMMARY'),
        const SizedBox(height: ZapSpacing.md),
        _DecisionSummary(
            decisions: decisions, allDecided: allDecided),
        const SizedBox(height: ZapSpacing.lg),

        // Gate
        _GateCard(allDecided: allDecided, passed: gatePassed,
            onOpen: () =>
                ref.read(_gatePassedProvider.notifier).state = true),
        const SizedBox(height: ZapSpacing.xl),

        // Next
        if (gatePassed) ...[
          const _SectionLabel('NEXT  ·  DAYS 138-140'),
          const SizedBox(height: ZapSpacing.md),
          const _NextCard(),
        ],
      ],
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final int            index;
  final _IterationItem item;
  final _Decision?     decision;
  final ValueChanged<_Decision> onDecide;
  const _DecisionCard({
    required this.index,
    required this.item,
    required this.decision,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: decision != null
            ? _decColor(decision!).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: decision != null
              ? _decColor(decision!).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: item.priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(item.priority,
                  style: TextStyle(
                      color: item.priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(item.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: ZapSpacing.xs),
          Row(children: [
            const Icon(Icons.person_rounded, color: Color(0xFF6B7280), size: 11),
            const SizedBox(width: ZapSpacing.xs),
            Text(item.source,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            const SizedBox(width: ZapSpacing.md),
            const Icon(Icons.timer_rounded, color: Color(0xFF6B7280), size: 11),
            const SizedBox(width: ZapSpacing.xs),
            Text(item.effort,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          Row(children: [
            _decBtn(_Decision.fix,     '✅ Fix D138-139',
                const Color(0xFF10B981), decision),
            const SizedBox(width: 6),
            _decBtn(_Decision.defer,   '⏰ Defer',
                const Color(0xFFF59E0B), decision),
            const SizedBox(width: 6),
            _decBtn(_Decision.wontFix, '❌ Won\'t fix',
                const Color(0xFFEF4444), decision),
          ]),
        ],
      ),
    );
  }

  Widget _decBtn(_Decision d, String label, Color color, _Decision? current) =>
      Expanded(
        child: GestureDetector(
          onTap: () => onDecide(d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: current == d
                  ? color.withOpacity(0.15)
                  : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: current == d
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: current == d ? color : const Color(0xFF4B5563),
                    fontSize: 9,
                    fontWeight: current == d
                        ? FontWeight.w700
                        : FontWeight.w400),
                textAlign: TextAlign.center),
          ),
        ),
      );

  Color _decColor(_Decision d) {
    switch (d) {
      case _Decision.fix:     return const Color(0xFF10B981);
      case _Decision.defer:   return const Color(0xFFF59E0B);
      case _Decision.wontFix: return const Color(0xFFEF4444);
    }
  }
}

class _DecisionSummary extends StatelessWidget {
  final Map<int, _Decision> decisions;
  final bool allDecided;
  const _DecisionSummary(
      {required this.decisions, required this.allDecided});

  @override
  Widget build(BuildContext context) {
    final toFix    = decisions.values.where((d) => d == _Decision.fix).length;
    final toDefer  = decisions.values.where((d) => d == _Decision.defer).length;
    final wontFix  = decisions.values.where((d) => d == _Decision.wontFix).length;
    final decided  = decisions.length;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: allDecided
            ? const Color(0xFF10B981).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: allDecided
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Row(children: [
          _summaryBox('$toFix', 'Fix', const Color(0xFF10B981)),
          const SizedBox(width: ZapSpacing.sm),
          _summaryBox('$toDefer', 'Defer', const Color(0xFFF59E0B)),
          const SizedBox(width: ZapSpacing.sm),
          _summaryBox('$wontFix', 'Won\'t fix', const Color(0xFFEF4444)),
          const SizedBox(width: ZapSpacing.sm),
          _summaryBox('${_kIterationItems.length - decided}',
              'Undecided', const Color(0xFF4B5563)),
        ]),
        if (allDecided) ...[
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'All items decided ✅',
            style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ]),
    );
  }

  Widget _summaryBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _GateCard extends StatelessWidget {
  final bool allDecided;
  final bool passed;
  final VoidCallback onOpen;
  const _GateCard({
    required this.allDecided,
    required this.passed,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (passed) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.12),
            const Color(0xFF10B981).withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: Column(children: [
          const Icon(Icons.verified_rounded,
              color: Color(0xFF10B981), size: 44),
          const SizedBox(height: ZapSpacing.md),
          const Text('Day 137 Gate Passed ✅',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Iteration plan confirmed:\n'
            'Days 138-139 fix 4 items → Day 140 tag v0.5-beta-final',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center,
            children: const [
              _Chip('DAU +96%',         Color(0xFF10B981)),
              _Chip('Crash 0.09%',      Color(0xFF10B981)),
              _Chip('Retention D7 43%', Color(0xFF10B981)),
              _Chip('4 items queued',   Color(0xFFF97316)),
              _Chip('Day 140 on track', Color(0xFF3B82F6)),
            ],
          ),
        ]),
      );
    }

    return GestureDetector(
      onTap: allDecided ? onOpen : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: allDecided
              ? const LinearGradient(
                  colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)])
              : null,
          color: allDecided ? null : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: allDecided
              ? [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
                ]
              : null,
          border: allDecided
              ? null
              : Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_open_rounded,
                color: allDecided
                    ? Colors.white
                    : const Color(0xFF4B5563),
                size: 20),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              allDecided
                  ? 'Open Day 137 gate → confirm iteration plan'
                  : 'Decide all 4 items above first',
              style: TextStyle(
                  color: allDecided
                      ? Colors.white
                      : const Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _row(const Color(0xFFF97316), 'Days 138-139',
            'Final polish — fix the 4 items decided today. '
            'No new features. Accessibility + security scan.'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF10B981), 'Day 140',
            'Tag v0.5-beta-final — all tests pass, '
            'production-ready app, ready for App Store submission.'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF3B82F6), 'Days 141-150',
            'AWS migration, performance testing, App Store assets, '
            'privacy policy, public launch preparation.'),
      ]),
    );
  }

  Widget _row(Color color, String days, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(days,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(action,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _infoBox({
  required IconData icon,
  required Color color,
  required String text,
}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ),
      ]),
    );
