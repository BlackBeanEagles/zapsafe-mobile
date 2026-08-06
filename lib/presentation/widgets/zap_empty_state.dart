/// ZapSafe empty list states — Day 212
///
/// Illustration area, helpful copy, and primary CTA for zero-item screens.
library;

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// Preset empty states for common list screens.
enum ZapEmptyKind {
  contacts,
  vault,
  notifications,
  journey,
  chat,
}

/// Copy + icon presets for [ZapEmptyKind].
class ZapEmptyMapper {
  ZapEmptyMapper._();

  static String title(ZapEmptyKind kind) => switch (kind) {
        ZapEmptyKind.contacts => 'No emergency contacts',
        ZapEmptyKind.vault => 'Your vault is empty',
        ZapEmptyKind.notifications => 'No notifications yet',
        ZapEmptyKind.journey => 'Your journey starts here',
        ZapEmptyKind.chat => 'No messages yet',
      };

  static String message(ZapEmptyKind kind) => switch (kind) {
        ZapEmptyKind.contacts =>
          'Add at least one Tier 1 contact so SOS alerts '
          'can reach someone you trust.',
        ZapEmptyKind.vault =>
          'SOS recordings and evidence clips appear here after '
          'your first alert or drill.',
        ZapEmptyKind.notifications =>
          'When ZapSafe sends alerts, delivery updates, or safety '
          'tips, they will show up in this feed.',
        ZapEmptyKind.journey =>
          'Complete onboarding steps and run your first drill '
          'to unlock your protection timeline.',
        ZapEmptyKind.chat =>
          'Start a secure chat with your emergency contacts '
          'or ZapSafe support when you need help.',
      };

  static String ctaLabel(ZapEmptyKind kind) => switch (kind) {
        ZapEmptyKind.contacts => 'Add first contact',
        ZapEmptyKind.vault => 'Run a safety drill',
        ZapEmptyKind.notifications => 'Enable notifications',
        ZapEmptyKind.journey => 'Start your journey',
        ZapEmptyKind.chat => 'Start a conversation',
      };

  static IconData icon(ZapEmptyKind kind) => switch (kind) {
        ZapEmptyKind.contacts => Icons.people_outline_rounded,
        ZapEmptyKind.vault => Icons.folder_open_rounded,
        ZapEmptyKind.notifications => Icons.notifications_none_rounded,
        ZapEmptyKind.journey => Icons.route_rounded,
        ZapEmptyKind.chat => Icons.chat_bubble_outline_rounded,
      };

  static Color accent(ZapEmptyKind kind) => switch (kind) {
        ZapEmptyKind.contacts => ZapColors.safe,
        ZapEmptyKind.vault => ZapColors.info,
        ZapEmptyKind.notifications => ZapColors.warning,
        ZapEmptyKind.journey => const Color(0xFF8B5CF6),
        ZapEmptyKind.chat => ZapColors.safe,
      };

  static String adoptScreen(ZapEmptyKind kind) => switch (kind) {
        ZapEmptyKind.contacts => 'Day 83 Contacts v2',
        ZapEmptyKind.vault => 'Day 82 Evidence Vault',
        ZapEmptyKind.notifications => 'Day 88 Notification History',
        ZapEmptyKind.journey => 'Day 45 Onboarding Step 5',
        ZapEmptyKind.chat => 'Day 207 Live Chat',
      };
}

/// Full-screen or in-list empty placeholder with illustration + CTA.
class ZapEmptyState extends StatelessWidget {
  final ZapEmptyKind? kind;
  final String? title;
  final String? message;
  final String? ctaLabel;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onPrimaryAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;
  final Widget? illustration;

  const ZapEmptyState({
    super.key,
    this.kind,
    this.title,
    this.message,
    this.ctaLabel,
    this.icon,
    this.accent,
    this.onPrimaryAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    this.compact = false,
    this.illustration,
  });

  /// Build from a preset [ZapEmptyKind].
  factory ZapEmptyState.preset({
    required ZapEmptyKind kind,
    VoidCallback? onPrimaryAction,
    String? secondaryLabel,
    VoidCallback? onSecondaryAction,
    bool compact = false,
  }) {
    return ZapEmptyState(
      kind: kind,
      onPrimaryAction: onPrimaryAction,
      secondaryLabel: secondaryLabel,
      onSecondaryAction: onSecondaryAction,
      compact: compact,
    );
  }

  String get _title =>
      title ?? (kind != null ? ZapEmptyMapper.title(kind!) : 'Nothing here yet');

  String get _message =>
      message ??
      (kind != null
          ? ZapEmptyMapper.message(kind!)
          : 'There is nothing to show in this list right now.');

  String? get _ctaLabel =>
      ctaLabel ?? (kind != null ? ZapEmptyMapper.ctaLabel(kind!) : null);

  IconData get _icon =>
      icon ?? (kind != null ? ZapEmptyMapper.icon(kind!) : Icons.inbox_rounded);

  Color get _accent =>
      accent ?? (kind != null ? ZapEmptyMapper.accent(kind!) : ZapColors.info);

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 36.0 : 52.0;
    final boxSize = compact ? 72.0 : 96.0;

    return Semantics(
      label: '$_title. $_message',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? ZapSpacing.md : ZapSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              illustration ??
                  _IllustrationBox(
                    icon: _icon,
                    accent: _accent,
                    iconSize: iconSize,
                    boxSize: boxSize,
                  ),
              SizedBox(height: compact ? ZapSpacing.md : ZapSpacing.lg),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 15 : 18,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (onPrimaryAction != null && _ctaLabel != null) ...[
                SizedBox(height: compact ? ZapSpacing.lg : ZapSpacing.xl),
                Semantics(
                  label: _ctaLabel!,
                  button: true,
                  child: FilledButton.icon(
                    onPressed: onPrimaryAction,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(_ctaLabel!),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(
                        compact ? 200 : double.infinity,
                        ZapSpacing.buttonHeight,
                      ),
                      backgroundColor: _accent,
                      foregroundColor: ZapColors.bgPrimary,
                    ),
                  ),
                ),
              ],
              if (onSecondaryAction != null && secondaryLabel != null) ...[
                const SizedBox(height: ZapSpacing.sm),
                Semantics(
                  label: secondaryLabel!,
                  button: true,
                  child: TextButton(
                    onPressed: onSecondaryAction,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(120, ZapSpacing.buttonHeight),
                    ),
                    child: Text(
                      secondaryLabel!,
                      style: const TextStyle(color: ZapColors.textSecondary),
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
}

class _IllustrationBox extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double iconSize;
  final double boxSize;

  const _IllustrationBox({
    required this.icon,
    required this.accent,
    required this.iconSize,
    required this.boxSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: boxSize + 28,
          height: boxSize + 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withOpacity(0.12), width: 2),
          ),
        ),
        Container(
          width: boxSize + 12,
          height: boxSize + 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.06),
          ),
        ),
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: ZapColors.bgElevated,
            borderRadius: BorderRadius.circular(boxSize * 0.22),
            border: Border.all(color: accent.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: accent),
        ),
      ],
    );
  }
}

/// Compact empty strip for filtered lists (e.g. vault search with zero matches).
class ZapEmptyInline extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ZapEmptyInline({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 28, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            Semantics(
              label: actionLabel!,
              button: true,
              child: TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
