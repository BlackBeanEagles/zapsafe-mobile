/// Day 367 — Ratings & Reviews Monitor
///
/// Section M (Days 366-370, Post-Launch Week 1): a manual-paste tool for
/// tracking Play Store / App Store ratings and reviews.
///
/// **There are no real reviews to show — there is no real store listing.**
/// Neither Google Play nor Apple expose a public API for reading reviews
/// from inside the app itself (both require the developer console / a
/// separate Reporting API with its own OAuth flow, not something this
/// Flutter app can call directly). So this is 100% correctly a manual-paste
/// tool: once a real listing exists and real reviews appear, paste them in
/// here to track sentiment and draft responses. The log starts empty and
/// stays empty until something is actually pasted.
///
/// Tag: 🟢 FRONTEND-ONLY · real manual-paste tool, no fabricated reviews.
///
/// Route: [AppRoutes.ratingsReviewsMonitor] → `/day-367-ratings-reviews-monitor`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFFBBF24);
const _kTabs = ['Reviews', 'Add review', 'Templates'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day367_ratings_reviews_v1';

enum _Platform { play, appStore }
enum _Sentiment { positive, neutral, negative }

String _platformLabel(_Platform p) => p == _Platform.play ? 'Google Play' : 'App Store';
String _sentimentLabel(_Sentiment s) => switch (s) {
      _Sentiment.positive => 'Positive',
      _Sentiment.neutral => 'Neutral',
      _Sentiment.negative => 'Negative',
    };
Color _sentimentColor(_Sentiment s) => switch (s) {
      _Sentiment.positive => ZapColors.safe,
      _Sentiment.neutral => ZapColors.info,
      _Sentiment.negative => ZapColors.danger,
    };

class _Review {
  const _Review({
    required this.id,
    required this.platform,
    required this.rating,
    required this.reviewerName,
    required this.text,
    required this.sentiment,
    required this.pastedAt,
    this.responseDraft,
  });

  final String id;
  final _Platform platform;
  final int rating;
  final String reviewerName;
  final String text;
  final _Sentiment sentiment;
  final DateTime pastedAt;
  final String? responseDraft;

  _Review copyWith({String? responseDraft}) => _Review(
        id: id, platform: platform, rating: rating, reviewerName: reviewerName,
        text: text, sentiment: sentiment, pastedAt: pastedAt,
        responseDraft: responseDraft ?? this.responseDraft,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'platform': platform.name, 'rating': rating,
        'reviewer_name': reviewerName, 'text': text, 'sentiment': sentiment.name,
        'pasted_at': pastedAt.toIso8601String(), 'response_draft': responseDraft,
      };

  factory _Review.fromJson(Map<String, dynamic> j) => _Review(
        id: j['id'] as String,
        platform: (j['platform'] as String?) == 'appStore' ? _Platform.appStore : _Platform.play,
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        reviewerName: j['reviewer_name'] as String? ?? '',
        text: j['text'] as String? ?? '',
        sentiment: switch (j['sentiment'] as String?) {
          'negative' => _Sentiment.negative,
          'neutral' => _Sentiment.neutral,
          _ => _Sentiment.positive,
        },
        pastedAt: DateTime.tryParse(j['pasted_at'] as String? ?? '') ?? DateTime.now(),
        responseDraft: j['response_draft'] as String?,
      );
}

// Response-template drafts, keyed by sentiment — real starter copy, filled
// with placeholders that must be edited per real review.
String _templateFor(_Sentiment s, String reviewerName) {
  final name = reviewerName.isEmpty ? 'there' : reviewerName;
  return switch (s) {
    _Sentiment.positive => '''Hi $name,

Thank you so much for the kind words and for trusting ZapSafe with your safety. It means a lot to hear this is working well for you.

If you ever run into an issue or have a feature request, our support team is at support@zapsafe.app.

— ZapSafe Team''',
    _Sentiment.neutral => '''Hi $name,

Thanks for taking the time to review ZapSafe. We'd love to hear more about what would make this a 5-star experience for you — feel free to reach out at support@zapsafe.app so we can look into it.

— ZapSafe Team''',
    _Sentiment.negative => '''Hi $name,

We're sorry to hear about your experience — this isn't the standard we hold ourselves to, especially for a safety app. Could you email support@zapsafe.app with more detail (device, what happened) so we can investigate properly? We take every safety-related report seriously.

— ZapSafe Team''',
  };
}

class _ReviewLogNotifier extends StateNotifier<List<_Review>> {
  _ReviewLogNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPrefsKey);
      if (raw != null) {
        state = raw.map((s) => _Review.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList()
          ..sort((a, b) => b.pastedAt.compareTo(a.pastedAt));
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefsKey, state.map((e) => jsonEncode(e.toJson())).toList());
    } catch (_) {}
  }

  void add(_Review r) {
    state = [r, ...state];
    _persist();
  }

  void setResponseDraft(String id, String draft) {
    state = state.map((r) => r.id == id ? r.copyWith(responseDraft: draft) : r).toList();
    _persist();
  }

  void remove(String id) {
    state = state.where((r) => r.id != id).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }
}

final _d367LogProvider = StateNotifierProvider<_ReviewLogNotifier, List<_Review>>((ref) => _ReviewLogNotifier());
final _d367TabProvider = StateProvider<int>((ref) => 0);

Map<String, dynamic> _monitorPayload(List<_Review> reviews) {
  final byPlatform = {for (final p in _Platform.values) p.name: reviews.where((r) => r.platform == p).length};
  final bySentiment = {for (final s in _Sentiment.values) s.name: reviews.where((r) => r.sentiment == s).length};
  final avgRating = reviews.isEmpty ? null : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  return {
    'endpoint': 'NONE — Play/App Store expose no in-app-readable public review API',
    'reviews_logged': reviews.length,
    'by_platform': byPlatform,
    'by_sentiment': bySentiment,
    'avg_rating': avgRating,
    'wire_note': 'Manual-paste tool · real store listing does not exist yet',
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day367RatingsReviewsMonitorScreen extends ConsumerWidget {
  const Day367RatingsReviewsMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(_d367LogProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day361_370.ratings_monitor_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: _kAccent.withOpacity(0.45))),
                child: Text('${reviews.length} logged', style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d367TabProvider), onSelect: (i) => ref.read(_d367TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d367TabProvider)) {
              0 => const _ReviewsTab(),
              1 => const _AddReviewTab(),
              _ => const _TemplatesTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Reviews ─────────────────────────────────────────────────────────────
class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(_d367LogProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
          child: const Text(
            'No real store listing exists yet, so there are no real reviews. '
            'Once one does, paste real reviews here via the "Add review" tab '
            '— nothing below is fabricated.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
            child: const Column(
              children: [
                Icon(Icons.rate_review_outlined, color: ZapColors.textMuted, size: 32),
                SizedBox(height: 8),
                Text('No reviews logged yet.', style: TextStyle(color: ZapColors.textMuted, fontSize: 12)),
              ],
            ),
          )
        else
          ...reviews.map((r) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: _sentimentColor(r.sentiment).withOpacity(0.35))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: ZapColors.bgSurface, borderRadius: BorderRadius.circular(4)),
                          child: Text(_platformLabel(r.platform), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 9)),
                        ),
                        const SizedBox(width: 6),
                        Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: _kAccent))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _sentimentColor(r.sentiment).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(_sentimentLabel(r.sentiment), style: TextStyle(color: _sentimentColor(r.sentiment), fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 16), onPressed: () => ref.read(_d367LogProvider.notifier).remove(r.id)),
                      ],
                    ),
                    if (r.reviewerName.isNotEmpty) Text(r.reviewerName, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(r.text, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                    if (r.responseDraft != null && r.responseDraft!.isNotEmpty) ...[
                      const Divider(height: 16),
                      const Text('Response draft:', style: TextStyle(color: ZapColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700)),
                      Text(r.responseDraft!, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, height: 1.4)),
                    ],
                  ],
                ),
              )),
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d367LogProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Clear all'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 1: Add review ─────────────────────────────────────────────────────────
class _AddReviewTab extends ConsumerStatefulWidget {
  const _AddReviewTab();

  @override
  ConsumerState<_AddReviewTab> createState() => _AddReviewTabState();
}

class _AddReviewTabState extends ConsumerState<_AddReviewTab> {
  final _nameController = TextEditingController();
  final _textController = TextEditingController();
  _Platform _platform = _Platform.play;
  _Sentiment _sentiment = _Sentiment.positive;
  int _rating = 5;

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paste the review text first.')));
      return;
    }
    ref.read(_d367LogProvider.notifier).add(_Review(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          platform: _platform,
          rating: _rating,
          reviewerName: _nameController.text.trim(),
          text: _textController.text.trim(),
          sentiment: _sentiment,
          pastedAt: DateTime.now(),
        ));
    _nameController.clear();
    _textController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review logged.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
          child: const Text(
            'Paste a real review from Play Console / App Store Connect once '
            'one exists. Nothing here is auto-fetched — there is no in-app '
            'reviews API available on either store.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Google Play'), selected: _platform == _Platform.play, onSelected: (_) => setState(() => _platform = _Platform.play)),
          ChoiceChip(label: const Text('App Store'), selected: _platform == _Platform.appStore, onSelected: (_) => setState(() => _platform = _Platform.appStore)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            const Text('Rating:', style: TextStyle(color: ZapColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 8),
            ...List.generate(5, (i) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: _kAccent),
                  onPressed: () => setState(() => _rating = i + 1),
                )),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(labelText: 'Reviewer name (optional)', filled: true, fillColor: ZapColors.bgCard, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextField(
          controller: _textController,
          maxLines: 4,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(labelText: 'Review text (paste here)', filled: true, fillColor: ZapColors.bgCard, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text('Sentiment tag:', style: TextStyle(color: ZapColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: _Sentiment.values.map((s) => ChoiceChip(
              label: Text(_sentimentLabel(s)),
              selected: _sentiment == s,
              selectedColor: _sentimentColor(s).withOpacity(0.25),
              onSelected: (_) => setState(() => _sentiment = s),
            )).toList()),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Log review'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }
}

// ── Tab 2: Templates ──────────────────────────────────────────────────────────
class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(_d367LogProvider);
    final payload = _monitorPayload(reviews);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Response-template drafts', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const Text('Real starter copy per sentiment — edit before actually replying to a real review.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
        const SizedBox(height: ZapSpacing.md),
        ..._Sentiment.values.map((s) => Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.md),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: _sentimentColor(s).withOpacity(0.35))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_sentimentLabel(s), style: TextStyle(color: _sentimentColor(s), fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 6),
                  SelectableText(_templateFor(s, ''), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _templateFor(s, '')));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template copied.')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy template'),
                  ),
                ],
              ),
            )),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Log summary', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_kJsonEncoder.convert(payload), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(label: const Text('Day 366 SOS Dashboard'), onPressed: () => context.push(AppRoutes.liveSosDashboard)),
        ]),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
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
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2))),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(color: selected ? _kAccent : ZapColors.textMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, fontSize: 12)),
              ),
            ),
          );
        }),
      ),
    );
  }
}
