import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import 'zap_button.dart';

/// Visual intent of a dialog — drives icon color and primary action color.
enum ZapDialogIntent {
  /// Blue info — general confirmation.
  info,

  /// Green safe — positive confirmation (verify, save).
  safe,

  /// Orange warning — caution before proceeding.
  warning,

  /// Red destructive — irreversible action (delete, wipe).
  danger,
}

/// ZapSafe themed dialog system.
///
/// Replaces Flutter's stock [showDialog]/[AlertDialog] with a system that:
/// - Uses the design tokens (colors, typography, spacing)
/// - Has 75dp buttons (WCAG AAA)
/// - Returns a typed result via `await`
/// - Provides preset shapes for common use cases
///
/// Usage:
/// ```dart
/// final confirmed = await ZapDialog.confirm(context,
///   title: 'Delete contact?',
///   message: 'Aarti Sharma will be removed from your Tier 1.',
///   confirmLabel: 'DELETE',
///   intent: ZapDialogIntent.danger,
/// );
/// if (confirmed == true) {
///   ...
/// }
/// ```
class ZapDialog {
  ZapDialog._();

  // ─── alert: a single OK button (typically info) ────────────────────────

  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = 'OK',
    ZapDialogIntent intent = ZapDialogIntent.info,
    IconData? icon,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => _ZapDialogShell(
        title: title,
        message: message,
        intent: intent,
        icon: icon,
        actions: [
          ZapButton.elevated(
            label: okLabel,
            intent: _btnIntentFor(intent),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ─── confirm: cancel + confirm. Returns true if confirmed. ─────────────

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'CONFIRM',
    String cancelLabel = 'CANCEL',
    ZapDialogIntent intent = ZapDialogIntent.info,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => _ZapDialogShell(
        title: title,
        message: message,
        intent: intent,
        icon: icon,
        actions: [
          ZapButton.outlined(
            label: cancelLabel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(width: ZapSpacing.md),
          ZapButton.elevated(
            label: confirmLabel,
            intent: _btnIntentFor(intent),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  // ─── destructive: red confirm, intent-locked to danger ─────────────────

  static Future<bool?> destructive(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'DELETE',
    String cancelLabel = 'CANCEL',
    IconData? icon,
  }) {
    return confirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      intent: ZapDialogIntent.danger,
      icon: icon ?? Icons.delete_forever,
      barrierDismissible: false, // force the user to choose
    );
  }

  // ─── Internal helpers ──────────────────────────────────────────────────

  static ZapButtonIntent _btnIntentFor(ZapDialogIntent intent) {
    switch (intent) {
      case ZapDialogIntent.info:
        return ZapButtonIntent.info;
      case ZapDialogIntent.safe:
        return ZapButtonIntent.safe;
      case ZapDialogIntent.warning:
        return ZapButtonIntent.warning;
      case ZapDialogIntent.danger:
        return ZapButtonIntent.danger;
    }
  }
}

/// The shared dialog body — handles icon, title, message, and action row.
class _ZapDialogShell extends StatelessWidget {
  final String title;
  final String message;
  final ZapDialogIntent intent;
  final IconData? icon;
  final List<Widget> actions;

  const _ZapDialogShell({
    required this.title,
    required this.message,
    required this.intent,
    required this.actions,
    this.icon,
  });

  Color _accentColor() {
    switch (intent) {
      case ZapDialogIntent.info:
        return ZapColors.info;
      case ZapDialogIntent.safe:
        return ZapColors.safe;
      case ZapDialogIntent.warning:
        return ZapColors.warning;
      case ZapDialogIntent.danger:
        return ZapColors.danger;
    }
  }

  IconData _defaultIcon() {
    switch (intent) {
      case ZapDialogIntent.info:
        return Icons.info_outline_rounded;
      case ZapDialogIntent.safe:
        return Icons.check_circle_outline_rounded;
      case ZapDialogIntent.warning:
        return Icons.warning_amber_rounded;
      case ZapDialogIntent.danger:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final iconData = icon ?? _defaultIcon();

    return Dialog(
      backgroundColor: ZapColors.bgCard,
      elevation: 12,
      insetPadding: const EdgeInsets.all(ZapSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        side: BorderSide(color: accent.withOpacity(0.4), width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(ZapSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: accent, size: 28),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: ZapTypography.headlineSmall.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.lg),
              Text(
                message,
                style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: ZapSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
