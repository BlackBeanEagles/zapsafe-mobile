/// Day 121 — Analyse First Feedback Batch
///
/// 1–2 weeks after the Day 120 beta launch, 1,000 testers have used the app.
/// This screen analyses three data sources:
///   1. Sentry — crash frequency, affected devices, root causes
///   2. Feedback Form — star ratings, category breakdown, top complaints
///   3. False Positive Reports — which model over-triggers, FP rate
///
/// Output: prioritised bug list (P0–P3), top feature requests, sentiment
/// summary, and action items for Days 122-140.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _expandedBugProvider    = StateProvider<int?>((ref) => null);

// ── Data ───────────────────────────────────────────────────────────────────────
class _Bug {
  final String priority;
  final Color  priorityColor;
  final String title;
  final String source;
  final double affectedPct;
  final int    affectedUsers;
  final String rootCause;
  final String fix;
  const _Bug({
    required this.priority,
    required this.priorityColor,
    required this.title,
    required this.source,
    required this.affectedPct,
    required this.affectedUsers,
    required this.rootCause,
    required this.fix,
  });
}

const _kBugs = [
  _Bug(
    priority: 'P0', priorityColor: Color(0xFFEF4444),
    title: 'App crashes on Android 11 when sending SOS SMS',
    source: 'Sentry · android_11_sms_crash',
    affectedPct: 5.1, affectedUsers: 51,
    rootCause: 'Android 11 changed SMS permission API — old requestPermissions() call throws SecurityException',
    fix: 'Update to ActivityResultContracts.RequestPermission, add try-catch around SMS send',
  ),
  _Bug(
    priority: 'P0', priorityColor: Color(0xFFEF4444),
    title: 'Out-of-memory crash after 20 min on iPhone 7',
    source: 'Sentry · ios_oom_location',
    affectedPct: 3.2, affectedUsers: 32,
    rootCause: 'CLLocationManager listener never disposed — holds reference to full GPS buffer',
    fix: 'Call locationManager.stopUpdatingLocation() in viewDidDisappear, reduce GPS accuracy to kCLLocationAccuracyHundredMeters on LITE tier',
  ),
  _Bug(
    priority: 'P1', priorityColor: Color(0xFFF97316),
    title: 'SOS notification delay > 30s on Android 13 (Samsung)',
    source: 'Feedback · category: performance (61% report)',
    affectedPct: 2.8, affectedUsers: 28,
    rootCause: 'Samsung Android 13 aggressively kills background services — FCM push delayed by Doze mode',
    fix: 'Add setExactAndAllowWhileIdle() alarm as fallback, request SCHEDULE_EXACT_ALARM permission',
  ),
  _Bug(
    priority: 'P1', priorityColor: Color(0xFFF97316),
    title: 'TFLite scream model crashes on low-RAM devices (< 2 GB)',
    source: 'Sentry · tflite_oom_lite_tier',
    affectedPct: 1.9, affectedUsers: 19,
    rootCause: 'INT8 model still allocates 180 MB tensor arena — exceeds available memory on LITE tier phones',
    fix: 'Switch LITE tier to stub model (returns 0.0 score), show "Detection unavailable on this device"',
  ),
  _Bug(
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    title: 'Hindi text overflows SOS cancel button',
    source: 'Feedback · category: UX (14 reports)',
    affectedPct: 0.4, affectedUsers: 4,
    rootCause: 'Hindi string 42 chars vs English 12 — fixed-width button clips text',
    fix: 'Replace SizedBox(width:) with IntrinsicWidth + padding, set maxLines:2 on button label',
  ),
  _Bug(
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    title: 'WebSocket chat disconnects silently when app backgrounds',
    source: 'Feedback · category: UX (9 reports)',
    affectedPct: 0.3, affectedUsers: 3,
    rootCause: 'No reconnect logic on app resume — stream silently stale',
    fix: 'Add AppLifecycleState.resumed listener → call channel.sink.add(pingMessage) → reconnect on error',
  ),
  _Bug(
    priority: 'P3', priorityColor: Color(0xFF3B82F6),
    title: 'Dark mode icon tint off on older Android (API 29)',
    source: 'Feedback · category: UX (5 reports)',
    affectedPct: 0.1, affectedUsers: 1,
    rootCause: 'VectorDrawable tint not applied below API 30',
    fix: 'Use explicit colorFilter on Image.asset() for API ≤ 30 devices',
  ),
];

const _kFeatureRequests = [
  (Icons.watch_rounded,       Color(0xFF3B82F6), 'Wearable support',        'Trigger SOS from smartwatch', 47),
  (Icons.share_rounded,       Color(0xFF10B981), 'Share safety status',     'Send "I\'m safe" update to contacts', 31),
  (Icons.dark_mode_rounded,   Color(0xFF8B5CF6), 'Scheduled quiet hours',   'Auto-disable detection during sleep', 28),
];

// ── Ratings data ──
const _kRatings = [
  (5, 0.52, Color(0xFF10B981)),
  (4, 0.28, Color(0xFF3B82F6)),
  (3, 0.11, Color(0xFFF59E0B)),
  (2, 0.05, Color(0xFFF97316)),
  (1, 0.04, Color(0xFFEF4444)),
];

// ── Category breakdown ──
const _kCategories = [
  ('Performance',      0.38, Color(0xFFEF4444)),
  ('False alarm',      0.24, Color(0xFFF59E0B)),
  ('General feedback', 0.19, Color(0xFF3B82F6)),
  ('UX issue',         0.12, Color(0xFF8B5CF6)),
  ('Crash report',     0.07, Color(0xFFF97316)),
];

// ── FP data ──
const _kFpModels = [
  ('M1 Scream',    0.092, Color(0xFFEF4444), 'Movie audio / music triggers'),
  ('M2 Motion',    0.041, Color(0xFFF97316), 'Running / cycling motion'),
  ('M9 DCS Fusion',0.023, Color(0xFFF59E0B), 'Combined false signals'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day121FeedbackAnalysisScreen extends ConsumerWidget {
  const Day121FeedbackAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 121 · Feedback Analysis'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Source tabs
            const _SectionLabel('DATA SOURCES'),
            const SizedBox(height: ZapSpacing.md),
            _SourceTabs(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.md),

            // Tab content
            if (tab == 0) const _SentryTab(),
            if (tab == 1) const _FeedbackTab(),
            if (tab == 2) const _FalsePositiveTab(),
            const SizedBox(height: ZapSpacing.xl),

            // Bug list
            const _SectionLabel('PRIORITISED BUG LIST  ·  TOP 7'),
            const SizedBox(height: ZapSpacing.md),
            const _BugList(),
            const SizedBox(height: ZapSpacing.xl),

            // Feature requests
            const _SectionLabel('TOP FEATURE REQUESTS'),
            const SizedBox(height: ZapSpacing.md),
            const _FeatureRequests(),
            const SizedBox(height: ZapSpacing.xl),

            // Sentiment + action items
            const _SectionLabel('USER SENTIMENT  ·  SUMMARY'),
            const SizedBox(height: ZapSpacing.md),
            const _SentimentCard(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('ACTION ITEMS  ·  DAYS 122-140'),
            const SizedBox(height: ZapSpacing.md),
            const _ActionItems(),
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
          colors: [Color(0xFF1A1000), Color(0xFF0D0900), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 121', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Week 2 post-launch', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text('Analyse First\nFeedback Batch',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '1,000 testers · 14 days · 312 feedback reports · '
            '105 Sentry crashes · 78 false positive reports. '
            'Three data sources → one prioritised action list.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('312',  'Feedback',  Color(0xFF3B82F6)),
            _HStat('105',  'Crashes',   Color(0xFFEF4444)),
            _HStat('78',   'FP reports',Color(0xFFF59E0B)),
            _HStat('4.2★', 'Avg rating',Color(0xFF10B981)),
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
  final Color color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
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

// ── Source tabs ────────────────────────────────────────────────────────────────
class _SourceTabs extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _SourceTabs({required this.active, required this.onSelect});

  static const _tabs = [
    (Icons.bug_report_rounded,    Color(0xFFEF4444), 'Sentry'),
    (Icons.rate_review_rounded,   Color(0xFF3B82F6), 'Feedback'),
    (Icons.warning_amber_rounded, Color(0xFFF59E0B), 'False +ve'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_tabs.length, (i) {
        final (icon, color, label) = _tabs[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < _tabs.length - 1 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon, color: isActive ? color : const Color(0xFF4B5563), size: 20),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                      color: isActive ? color : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    )),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Sentry tab ─────────────────────────────────────────────────────────────────
class _SentryTab extends StatelessWidget {
  const _SentryTab();

  static const _crashes = [
    ('Android 11 SMS crash',   51, Color(0xFFEF4444), 'P0'),
    ('iOS OOM / location',     32, Color(0xFFEF4444), 'P0'),
    ('TFLite OOM LITE tier',   19, Color(0xFFF97316), 'P1'),
    ('Notification delay',     28, Color(0xFFF97316), 'P1'),
    ('WebSocket silent drop',   3, Color(0xFFF59E0B), 'P2'),
  ];

  static const _devices = [
    ('Samsung Android 11',  0.34, Color(0xFFEF4444)),
    ('iPhone 7 iOS 15',     0.22, Color(0xFFF97316)),
    ('Xiaomi Android 12',   0.18, Color(0xFFF59E0B)),
    ('Pixel 6 Android 13',  0.14, Color(0xFF3B82F6)),
    ('Other',               0.12, Color(0xFF9CA3AF)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Crash overview
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(Icons.bar_chart_rounded, const Color(0xFFEF4444),
                'Total crashes', '105'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            ..._crashes.map((c) {
              final (title, count, color, priority) = c;
              return Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(priority,
                        style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  Text('$count users',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              );
            }),
          ],
        )),
        const SizedBox(height: ZapSpacing.md),
        // Device breakdown
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crash by device / OS',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: ZapSpacing.md),
            ..._devices.map((d) {
              final (device, frac, color) = d;
              return Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(device,
                          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12))),
                      Text('${(frac * 100).round()}%',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: ZapSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: frac,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        )),
      ],
    );
  }
}

// ── Feedback tab ───────────────────────────────────────────────────────────────
class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab();

  @override
  Widget build(BuildContext context) {
    double avgRating = 0;
    for (final (stars, frac, _) in _kRatings) {
      avgRating += stars * frac;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating distribution
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 36,
                        fontWeight: FontWeight.w900)),
                const Text('avg rating · 312 reviews',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              ]),
              const Spacer(),
              Column(
                children: List.generate(5, (i) => Icon(Icons.star_rounded,
                    color: i < avgRating.round()
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF2A2A2A),
                    size: 20)),
              ),
            ]),
            const SizedBox(height: ZapSpacing.lg),
            ..._kRatings.map((r) {
              final (stars, frac, color) = r;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Text('$stars★',
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: frac,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  SizedBox(
                    width: 32,
                    child: Text('${(frac * 100).round()}%',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                        textAlign: TextAlign.end),
                  ),
                ]),
              );
            }),
          ],
        )),
        const SizedBox(height: ZapSpacing.md),
        // Category breakdown
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feedback categories',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: ZapSpacing.md),
            ..._kCategories.map((c) {
              final (label, frac, color) = c;
              return Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(label,
                      style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12))),
                  Text('${(frac * 100).round()}%',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              );
            }),
            const SizedBox(height: ZapSpacing.md),
            // Top complaint
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.format_quote_rounded, color: Color(0xFFEF4444), size: 16),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '"SOS notification takes too long on Samsung" — 61% of performance reports',
                    style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5),
                  ),
                ),
              ]),
            ),
          ],
        )),
      ],
    );
  }
}

// ── False positive tab ─────────────────────────────────────────────────────────
class _FalsePositiveTab extends StatelessWidget {
  const _FalsePositiveTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall FP rate
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('7.8%',
                      style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 36,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('< 10% target ✓',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const Text('overall false positive rate · 78 / 1,000 SOS events',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: ZapSpacing.lg),
            const Text('By detection model',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: ZapSpacing.md),
            ..._kFpModels.map((m) {
              final (name, rate, color, trigger) = m;
              return Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                      Text('${(rate * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: ZapSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: rate / 0.15,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text('Common cause: $trigger',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                  ],
                ),
              );
            }),
          ],
        )),
        const SizedBox(height: ZapSpacing.md),
        // Recommendation
        _card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.tips_and_updates_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: ZapSpacing.sm),
              Text('Recommendation',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: ZapSpacing.md),
            ...[
              'Raise M1 scream confidence threshold from 0.80 → 0.88 (Days 124-125)',
              'Add "are you watching media?" context check before triggering',
              'Retrain M1 with 78 new false-alarm mel-spectrograms from beta users',
            ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.arrow_right_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: ZapSpacing.xs),
                    Expanded(child: Text(t,
                        style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.5))),
                  ]),
                )),
          ],
        )),
      ],
    );
  }
}

// ── Bug list ───────────────────────────────────────────────────────────────────
class _BugList extends ConsumerWidget {
  const _BugList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedBugProvider);

    return Column(
      children: _kBugs.asMap().entries.map((e) {
        final i     = e.key;
        final bug   = e.value;
        final isOpen = expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedBugProvider.notifier).state =
              isOpen ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: isOpen
                  ? bug.priorityColor.withOpacity(0.07)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: isOpen
                    ? bug.priorityColor.withOpacity(0.4)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: bug.priorityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: bug.priorityColor.withOpacity(0.35)),
                    ),
                    child: Center(
                      child: Text(bug.priority,
                          style: TextStyle(
                              color: bug.priorityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bug.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        Expanded(child: Text(bug.source,
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 10, fontFamily: 'monospace'),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${bug.affectedUsers} users (${bug.affectedPct}%)',
                            style: TextStyle(
                                color: bug.priorityColor, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  )),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF4B5563), size: 18),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(children: [
                          const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                          _detailRow('Root cause', bug.rootCause, const Color(0xFFEF4444)),
                          const SizedBox(height: ZapSpacing.sm),
                          _detailRow('Fix', bug.fix, const Color(0xFF10B981)),
                        ]),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _detailRow(String label, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))),
      ]),
    );
  }
}

// ── Feature requests ───────────────────────────────────────────────────────────
class _FeatureRequests extends StatelessWidget {
  const _FeatureRequests();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kFeatureRequests.asMap().entries.map((e) {
        final i = e.key;
        final (icon, color, title, desc, votes) = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${i + 1}  $title',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$votes votes',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Sentiment card ─────────────────────────────────────────────────────────────
class _SentimentCard extends StatelessWidget {
  const _SentimentCard();

  @override
  Widget build(BuildContext context) {
    const sentiments = [
      (Icons.sentiment_very_satisfied_rounded, Color(0xFF10B981), 'Satisfied',  52),
      (Icons.sentiment_satisfied_rounded,      Color(0xFF3B82F6), 'Positive',   28),
      (Icons.sentiment_neutral_rounded,        Color(0xFFF59E0B), 'Neutral',    12),
      (Icons.sentiment_dissatisfied_rounded,   Color(0xFFEF4444), 'Frustrated',  8),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: sentiments.map((s) {
            final (icon, color, label, pct) = s;
            return Column(children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: ZapSpacing.xs),
              Text('$pct%',
                  style: TextStyle(
                      color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
            ]);
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.format_quote_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(
              '"Love the concept — scream detection is impressive. '
              'Main issue is Samsung notification delay. Fix that and I\'ll rate 5★."',
              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Action items ───────────────────────────────────────────────────────────────
class _ActionItems extends StatelessWidget {
  const _ActionItems();

  static const _items = [
    (Color(0xFFEF4444), 'Days 122-123', 'Fix top 3 P0 crashes → release hotfix v0.5.1'),
    (Color(0xFFF97316), 'Days 124-125', 'Fix false positive UX — add explanation screen, raise M1 threshold'),
    (Color(0xFFF59E0B), 'Day 126',      'Fix UI bugs (Hindi overflow, contrast, icon tint)'),
    (Color(0xFF3B82F6), 'Days 127-128', 'Fix Samsung notification delay (Doze mode workaround)'),
    (Color(0xFF8B5CF6), 'Days 129-130', 'Performance optimisation — cold start, battery, memory'),
    (Color(0xFF10B981), 'Day 135',      'Release v0.5.2 build with all fixes bundled'),
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
        children: _items.asMap().entries.map((e) {
          final i = e.key;
          final (color, days, action) = e.value;
          final isLast = i == _items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(days,
                        style: TextStyle(
                            color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    Text(action,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, height: 1.4)),
                  ],
                )),
              ]),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: child,
    );

Widget _row(IconData icon, Color color, String label, String value) => Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: ZapSpacing.sm),
      Expanded(child: Text(label,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
