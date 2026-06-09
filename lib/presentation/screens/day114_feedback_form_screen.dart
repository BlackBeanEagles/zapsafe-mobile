/// Day 114 — Full Feedback Form Screen
///
/// Structured feedback form: 5-star rating + category dropdown (5 options)
/// + multiline text input. Validates before submit. Mock POST to
/// /api/v1/feedback/submit. Shows loading → success → auto-dismiss.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _FeedbackCategory {
  general('General feedback',       Icons.chat_bubble_outline_rounded,  Color(0xFF3B82F6)),
  crash(  'Crash report',           Icons.bug_report_rounded,            Color(0xFFEF4444)),
  falseAlarm('False alarm (SOS)',   Icons.warning_amber_rounded,         Color(0xFFF59E0B)),
  uxIssue('UX issue',               Icons.touch_app_rounded,             Color(0xFF8B5CF6)),
  performance('Performance issue',  Icons.speed_rounded,                 Color(0xFF10B981));

  final String label;
  final IconData icon;
  final Color color;
  const _FeedbackCategory(this.label, this.icon, this.color);
}

enum _SubmitState { idle, loading, success, error }

// ── Providers ──────────────────────────────────────────────────────────────────
final _ratingProvider   = StateProvider<int>((ref) => 5);
final _categoryProvider = StateProvider<_FeedbackCategory?>((ref) => null);
final _submitProvider   = StateProvider<_SubmitState>((ref) => _SubmitState.idle);

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day114FeedbackFormScreen extends ConsumerStatefulWidget {
  const Day114FeedbackFormScreen({super.key});

  @override
  ConsumerState<Day114FeedbackFormScreen> createState() =>
      _Day114FeedbackFormScreenState();
}

class _Day114FeedbackFormScreenState
    extends ConsumerState<Day114FeedbackFormScreen> {
  final _messageCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final category = ref.read(_categoryProvider);
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    ref.read(_submitProvider.notifier).state = _SubmitState.loading;

    // Mock POST /api/v1/feedback/submit
    await Future.delayed(const Duration(milliseconds: 1400));

    ref.read(_submitProvider.notifier).state = _SubmitState.success;

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).maybePop();
  }

  void _reset() {
    ref.read(_ratingProvider.notifier).state   = 5;
    ref.read(_categoryProvider.notifier).state = null;
    ref.read(_submitProvider.notifier).state   = _SubmitState.idle;
    _messageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(_submitProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 114 · Feedback Form'),
        elevation: 0,
        actions: [
          if (submitState == _SubmitState.idle ||
              submitState == _SubmitState.error)
            TextButton(
              onPressed: _reset,
              child: const Text(
                'Reset',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: submitState == _SubmitState.success
            ? _SuccessView(key: const ValueKey('success'), onReset: _reset)
            : submitState == _SubmitState.loading
                ? const _LoadingView(key: ValueKey('loading'))
                : _FormView(
                    key: const ValueKey('form'),
                    formKey: _formKey,
                    messageCtrl: _messageCtrl,
                    onSubmit: _submit,
                  ),
      ),
    );
  }
}

// ── Form view ──────────────────────────────────────────────────────────────────
class _FormView extends ConsumerWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController messageCtrl;
  final VoidCallback onSubmit;

  const _FormView({
    super.key,
    required this.formKey,
    required this.messageCtrl,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating   = ref.watch(_ratingProvider);
    final category = ref.watch(_categoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // ── Star rating ──────────────────────────────────────────────
            const _SectionLabel('YOUR RATING'),
            const SizedBox(height: ZapSpacing.md),
            _StarRating(
              rating: rating,
              onChanged: (v) =>
                  ref.read(_ratingProvider.notifier).state = v,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Category ─────────────────────────────────────────────────
            const _SectionLabel('CATEGORY  ·  required'),
            const SizedBox(height: ZapSpacing.md),
            _CategoryPicker(
              selected: category,
              onSelected: (cat) =>
                  ref.read(_categoryProvider.notifier).state = cat,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Message ───────────────────────────────────────────────────
            const _SectionLabel('YOUR FEEDBACK  ·  required'),
            const SizedBox(height: ZapSpacing.md),
            TextFormField(
              controller: messageCtrl,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please describe your feedback' : null,
              decoration: InputDecoration(
                hintText: 'Describe the issue, suggestion, or experience in detail…',
                hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                errorStyle: const TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            // Payload preview
            const _PayloadNote(),
            const SizedBox(height: ZapSpacing.xl),

            // ── Submit button ─────────────────────────────────────────────
            _SubmitButton(
              rating: rating,
              category: category,
              onTap: onSubmit,
            ),
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
          colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2E), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_rounded,
                    color: Color(0xFF3B82F6), size: 13),
                SizedBox(width: 5),
                Text(
                  '⚡  BETA  ·  DAY 114',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Send Feedback',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Rate your experience, pick a category, and describe the issue. '
            'Your report goes to POST /api/v1/feedback/submit and directly '
            'shapes the next ZapSafe build.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Star rating ────────────────────────────────────────────────────────────────
class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  const _StarRating({required this.rating, required this.onChanged});

  static const _labels = ['Terrible', 'Poor', 'Okay', 'Good', 'Excellent'];
  static const _labelColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < rating;
              return GestureDetector(
                onTap: () => onChanged(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedScale(
                    scale: filled ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF4B5563),
                      size: 40,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: ZapSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              rating > 0 ? _labels[rating - 1] : 'Tap to rate',
              key: ValueKey(rating),
              style: TextStyle(
                color: rating > 0
                    ? _labelColors[rating - 1]
                    : const Color(0xFF6B7280),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category picker ────────────────────────────────────────────────────────────
class _CategoryPicker extends StatelessWidget {
  final _FeedbackCategory? selected;
  final ValueChanged<_FeedbackCategory> onSelected;
  const _CategoryPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _FeedbackCategory.values.map((cat) {
        final isSelected = selected == cat;
        return GestureDetector(
          onTap: () => onSelected(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? cat.color.withOpacity(0.12)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: isSelected
                    ? cat.color.withOpacity(0.6)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text(
                    cat.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: cat.color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Payload note ───────────────────────────────────────────────────────────────
class _PayloadNote extends StatelessWidget {
  const _PayloadNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POST  /api/v1/feedback/submit',
            style: TextStyle(
              color: Color(0xFF79C0FF),
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '{ rating, category, message, app_version, timestamp }',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Submit button ──────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final int rating;
  final _FeedbackCategory? category;
  final VoidCallback onTap;
  const _SubmitButton(
      {required this.rating, required this.category, required this.onTap});

  bool get _ready => rating > 0 && category != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _ready ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: _ready
              ? const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                )
              : null,
          color: _ready ? null : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          boxShadow: _ready
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
          border: _ready
              ? null
              : Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send_rounded,
              color: _ready ? Colors.white : const Color(0xFF4B5563),
              size: 18,
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              _ready ? 'Submit Feedback' : 'Select rating & category first',
              style: TextStyle(
                color: _ready ? Colors.white : const Color(0xFF4B5563),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading view ───────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF3B82F6),
            strokeWidth: 2.5,
          ),
          SizedBox(height: ZapSpacing.lg),
          Text(
            'Sending feedback…',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Success view ───────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onReset;
  const _SuccessView({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF10B981),
                size: 44,
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),
            const Text(
              'Thank you!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Your feedback has been submitted.\nWe read every report and act on it.',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.xxxl),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.xl, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: const Text(
                  'Submit another',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
