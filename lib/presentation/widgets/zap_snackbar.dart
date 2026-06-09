import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// Semantic intent of a snackbar — picks the leading icon and accent color.
enum ZapSnackbarIntent {
  /// Green check — successful action (saved, verified, sent).
  success,

  /// Red alert — destructive or failed action (delete failed, network down).
  danger,

  /// Orange warning — caution (battery low, GPS weak).
  warning,

  /// Blue info — neutral status (sync started, drill scheduled).
  info,
}

/// Toast/snackbar wrapper used everywhere in ZapSafe.
///
/// Shows a themed snackbar with an icon + label + optional action button.
/// Uses the global [ScaffoldMessenger] so it survives screen pushes.
///
/// Usage:
/// ```dart
/// ZapSnackbar.success(context, 'Contact verified');
/// ZapSnackbar.danger(context, 'SOS dispatch failed', action: 'RETRY', onAction: retry);
/// ZapSnackbar.show(context,
///   message: 'Battery at 18% — Mode B evidence active',
///   intent: ZapSnackbarIntent.warning,
/// );
/// ```
class ZapSnackbar {
  ZapSnackbar._();

  // ─── Static API ────────────────────────────────────────────────────────

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? action,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      intent: ZapSnackbarIntent.success,
      duration: duration,
      action: action,
      onAction: onAction,
    );
  }

  static void danger(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? action,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      intent: ZapSnackbarIntent.danger,
      duration: duration,
      action: action,
      onAction: onAction,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? action,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      intent: ZapSnackbarIntent.warning,
      duration: duration,
      action: action,
      onAction: onAction,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? action,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      intent: ZapSnackbarIntent.info,
      duration: duration,
      action: action,
      onAction: onAction,
    );
  }

  /// The full-control API — use the named-intent helpers above when possible.
  static void show(
    BuildContext context, {
    required String message,
    ZapSnackbarIntent intent = ZapSnackbarIntent.info,
    Duration duration = const Duration(seconds: 3),
    String? action,
    VoidCallback? onAction,
  }) {
    final (color, icon) = _styleFor(intent);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.all(ZapSpacing.lg),
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.md,
          ),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (action != null && onAction != null) ...[
                const SizedBox(width: ZapSpacing.sm),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md,
                      vertical: ZapSpacing.sm,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    action,
                    style: ZapTypography.labelMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Dismiss any currently-visible snackbar.
  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // ─── Internal helpers ──────────────────────────────────────────────────

  static (Color, IconData) _styleFor(ZapSnackbarIntent intent) {
    switch (intent) {
      case ZapSnackbarIntent.success:
        return (ZapColors.safe, Icons.check_circle);
      case ZapSnackbarIntent.danger:
        return (ZapColors.danger, Icons.error_rounded);
      case ZapSnackbarIntent.warning:
        return (ZapColors.warning, Icons.warning_rounded);
      case ZapSnackbarIntent.info:
        return (ZapColors.info, Icons.info_rounded);
    }
  }
}
