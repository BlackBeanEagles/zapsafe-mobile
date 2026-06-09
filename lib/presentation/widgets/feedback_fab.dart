import 'package:flutter/material.dart';

/// Floating Feedback Action Button — only shown in beta builds.
///
/// Usage (in any Scaffold):
/// ```dart
/// floatingActionButton: FeedbackFab(
///   visible: FlavorConfig.isBeta,
///   onTap: () => FeedbackSheet.show(context),
/// ),
/// ```
///
/// Or inside a [Stack] for precise positioning:
/// ```dart
/// Stack(children: [
///   child,
///   Positioned(bottom: 24, right: 16,
///     child: FeedbackFab(visible: FlavorConfig.isBeta, onTap: ...)),
/// ])
/// ```
class FeedbackFab extends StatelessWidget {
  /// Whether the button is visible.
  /// In production, pass `FlavorConfig.isBeta` — hides automatically in prod.
  final bool visible;

  /// Called when the button is tapped. Typically opens the feedback bottom-sheet.
  final VoidCallback? onTap;

  const FeedbackFab({
    super.key,
    this.visible = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return FloatingActionButton(
      heroTag: 'zap_feedback_fab',
      onPressed: onTap,
      backgroundColor: const Color(0xFFF97316),
      elevation: 6,
      tooltip: 'Send feedback',
      child: const Icon(Icons.feedback_rounded, color: Colors.white, size: 24),
    );
  }
}
