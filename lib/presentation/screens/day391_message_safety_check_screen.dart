/// Day 391 — Message Safety Check (REAL on-device model)
///
/// The first text model wired into this app, and the surface that
/// `DAY347_DISTRESS_TEXT_DECISION.md` said would have to exist before any
/// text model shipped.
///
/// ⚠️ **Tag: 🟢 REAL — a real `.tflite` runs on this screen.** Unlike the
/// Day 301-390 Section F-O screens, nothing here is mocked. The score comes
/// from `trac_aggression_v1.tflite` executing on-device.
///
/// ## Why this model ships and `distress_text_v1` does not
///
/// This reads **a message someone else sent the user** and asks "is this
/// hostile". `distress_text_v1` infers the *user's own* clinical state —
/// its positive classes are Anxiety, Depression and Suicidal. Those are
/// different products with different consent requirements, and Day 347
/// refused to slip the second one in behind a threshold constant. That
/// refusal still stands; this is not it arriving by the back door.
///
/// ## Consent posture, which is the whole design
///
/// * **User-initiated only.** Nothing is read in the background. The user
///   pastes a message and presses a button.
/// * **On-device.** No network call. The text never leaves the phone.
/// * **Not retained.** The field is cleared on leaving; nothing is written
///   to storage, logs or analytics.
/// * **Not an SOS trigger.** It informs the person reading it. It does not
///   escalate, notify contacts or feed the DCS fusion path.
///
/// ## Honest about the model
///
///     in-corpus (TRAC-1 dev)          0.8312
///     cross-corpus (Indo-HateSpeech)  0.7081   <- quote this one
///
/// The screen shows the 0.71 figure, not the 0.83, because 0.71 is what
/// describes the model on text it has never seen. It also shows the raw
/// score and an explicit "unclear" band rather than rounding a 0.5 to a
/// verdict it cannot support.
///
/// English and Hindi (both Devanagari and romanised). TRAC-1 is
/// **Apache-2.0** — the only permissively-licensed training corpus in the
/// project.
///
/// Route: [AppRoutes.messageSafetyCheck] → `/day-391-message-safety-check`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../data/services/trac_aggression_detector.dart';

const _kAccent = Color(0xFF6D28D9);

/// Loads once and is kept for the life of the app; 2.7 MB of interpreter is
/// not worth re-allocating per visit.
final tracAggressionDetectorProvider =
    FutureProvider<TracAggressionDetector?>((ref) async {
  final d = await TracAggressionDetector.tryLoad();
  ref.onDispose(() => d?.dispose());
  return d;
});

final _resultProvider = StateProvider<TracVerdict?>((ref) => null);

class Day391MessageSafetyCheckScreen extends ConsumerStatefulWidget {
  const Day391MessageSafetyCheckScreen({super.key});

  @override
  ConsumerState<Day391MessageSafetyCheckScreen> createState() =>
      _Day391State();
}

class _Day391State extends ConsumerState<Day391MessageSafetyCheckScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    // The pasted message is not retained anywhere, including here.
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _check(TracAggressionDetector d) {
    FocusScope.of(context).unfocus();
    ref.read(_resultProvider.notifier).state = d.classify(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tracAggressionDetectorProvider);
    final result = ref.watch(_resultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Safety Check'),
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Unavailable(detail: '$e'),
        data: (detector) {
          if (detector == null) {
            return const _Unavailable(
                detail: 'The model assets did not load on this device.');
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PrivacyCard(),
                const SizedBox(height: ZapSpacing.md),
                TextField(
                  controller: _controller,
                  maxLines: 6,
                  minLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Paste a message you received',
                    hintText: 'The text stays on this device.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: _kAccent),
                        onPressed: () => _check(detector),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Check this message'),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    OutlinedButton(
                      onPressed: () {
                        _controller.clear();
                        ref.read(_resultProvider.notifier).state = null;
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                if (result != null) ...[
                  const SizedBox(height: ZapSpacing.md),
                  _ResultCard(result: result),
                ],
                const SizedBox(height: ZapSpacing.lg),
                const _AccuracyCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFF5F3FF),
      child: Padding(
        padding: EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This runs on your phone',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: ZapSpacing.xs),
            Text('• Nothing is sent to a server — there is no network call.\n'
                '• Nothing is saved. The text is gone when you leave.\n'
                '• Nothing happens automatically. It only reads what you '
                'paste, when you press the button.\n'
                '• This does not raise an SOS or message your contacts.'),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final TracVerdict result;

  @override
  Widget build(BuildContext context) {
    late final Color colour;
    late final IconData icon;
    late final String title;
    late final String body;

    switch (result.verdict) {
      case Verdict.tooShort:
        colour = Colors.grey;
        icon = Icons.short_text_rounded;
        title = 'Not enough text';
        body = 'Paste at least a couple of words. A very short message does '
            'not give the model anything to read.';
      case Verdict.hostile:
        colour = const Color(0xFFB91C1C);
        icon = Icons.warning_amber_rounded;
        title = 'This reads as hostile';
        body = 'The wording matches patterns of aggressive or abusive '
            'messages. You know the context and the sender — trust that over '
            'this screen.';
      case Verdict.unclear:
        colour = const Color(0xFFB45309);
        icon = Icons.help_outline_rounded;
        title = 'Unclear';
        body = 'This sits between the model\'s two bands. It is genuinely '
            'undecided rather than mildly one way, and is shown as such '
            'instead of being rounded to an answer.';
      case Verdict.notHostile:
        colour = const Color(0xFF15803D);
        icon = Icons.check_circle_outline_rounded;
        title = 'This does not read as hostile';
        body = 'No strong aggressive wording found. That is not the same as '
            '"this message is safe" — threats can be calm, and the model '
            'only reads wording.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colour),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colour)),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(body),
            const SizedBox(height: ZapSpacing.sm),
            if (result.score != null)
              Text(
                'Score ${result.score!.toStringAsFixed(3)}  ·  '
                'hostile at ≥ ${TracAggressionDetector.kHostileThreshold}  ·  '
                '${result.tokenCount} words read',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
              ),
            if (result.truncated)
              const Padding(
                padding: EdgeInsets.only(top: ZapSpacing.xs),
                child: Text(
                  'Only the first 60 words were read — the model cannot see '
                  'past that, so the rest of this message was not checked.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFF8FAFC),
      child: Padding(
        padding: EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How accurate is this?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: ZapSpacing.xs),
            Text(
              'Measured AUC 0.71 on 58,477 messages from a corpus it was '
              'never trained on. It scores 0.83 on its own test split, but '
              '0.71 is the honest number for text it has not seen before — '
              'so that is the one quoted here.\n\n'
              'It reads English and Hindi. It reads wording only: it does '
              'not know your history with the sender, and it cannot detect '
              'a threat that is phrased politely.\n\n'
              'Treat it as a second opinion, never as a verdict.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: ZapSpacing.sm),
            const Text('Message check is unavailable',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: ZapSpacing.xs),
            Text(detail, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
