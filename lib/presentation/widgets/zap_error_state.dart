/// ZapSafe friendly error states — Day 210
///
/// User-facing error UI with plain-language copy. Never surfaces raw
/// [DioException] or stack traces to the user.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// Standard error categories mapped from HTTP / network failures.
enum ZapErrorKind {
  network,
  forbidden,
  server,
  timeout,
  generic,
}

/// Maps API failures to [ZapErrorKind] — safe for UI layer.
class ZapErrorMapper {
  ZapErrorMapper._();

  static ZapErrorKind kindFrom(Object? error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
          return ZapErrorKind.network;
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ZapErrorKind.timeout;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          if (code == 403 || code == 401) return ZapErrorKind.forbidden;
          if (code != null && code >= 500) return ZapErrorKind.server;
          return ZapErrorKind.generic;
        default:
          return ZapErrorKind.generic;
      }
    }
    return ZapErrorKind.generic;
  }

  /// User-safe message — never exposes exception class names.
  static String title(ZapErrorKind kind) => switch (kind) {
        ZapErrorKind.network => 'No internet connection',
        ZapErrorKind.forbidden => 'Access not allowed',
        ZapErrorKind.server => 'Something went wrong',
        ZapErrorKind.timeout => 'Request timed out',
        ZapErrorKind.generic => 'Could not load data',
      };

  static String message(ZapErrorKind kind) => switch (kind) {
        ZapErrorKind.network =>
          'ZapSafe could not reach the server. Your SOS and on-device '
          'features still work offline.',
        ZapErrorKind.forbidden =>
          'You do not have permission to view this. Sign in again or '
          'contact support if this seems wrong.',
        ZapErrorKind.server =>
          'Our servers hit a snag. Your data is safe — please try again '
          'in a moment.',
        ZapErrorKind.timeout =>
          'The server took too long to respond. Check your connection '
          'and try again.',
        ZapErrorKind.generic =>
          'We could not complete that request. Please try again.',
      };

  static bool showConnectionTip(ZapErrorKind kind) =>
      kind == ZapErrorKind.network || kind == ZapErrorKind.timeout;

  static IconData icon(ZapErrorKind kind) => switch (kind) {
        ZapErrorKind.network => Icons.wifi_off_rounded,
        ZapErrorKind.forbidden => Icons.lock_outline_rounded,
        ZapErrorKind.server => Icons.cloud_off_rounded,
        ZapErrorKind.timeout => Icons.timer_off_rounded,
        ZapErrorKind.generic => Icons.error_outline_rounded,
      };

  static Color accent(ZapErrorKind kind) => switch (kind) {
        ZapErrorKind.network => ZapColors.warning,
        ZapErrorKind.forbidden => ZapColors.info,
        ZapErrorKind.server => ZapColors.danger,
        ZapErrorKind.timeout => ZapColors.warning,
        ZapErrorKind.generic => ZapColors.danger,
      };
}

/// Friendly full-screen or inline error placeholder with Retry.
class ZapErrorState extends StatelessWidget {
  final ZapErrorKind kind;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;
  final bool showConnectionTip;

  const ZapErrorState({
    super.key,
    this.kind = ZapErrorKind.generic,
    this.title,
    this.message,
    this.onRetry,
    this.compact = false,
    this.showConnectionTip = true,
  });

  /// Build from any caught error — maps [DioException] safely.
  factory ZapErrorState.fromError({
    required Object? error,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    final kind = ZapErrorMapper.kindFrom(error);
    return ZapErrorState(
      kind: kind,
      onRetry: onRetry,
      compact: compact,
      showConnectionTip: ZapErrorMapper.showConnectionTip(kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ZapErrorMapper.accent(kind);
    final displayTitle = title ?? ZapErrorMapper.title(kind);
    final displayMessage = message ?? ZapErrorMapper.message(kind);
    final tip = showConnectionTip && ZapErrorMapper.showConnectionTip(kind);

    final iconSize = compact ? 36.0 : 52.0;

    return Semantics(
      label: '$displayTitle. $displayMessage',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? ZapSpacing.md : ZapSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize + 24,
                height: iconSize + 24,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ZapErrorMapper.icon(kind),
                  size: iconSize,
                  color: accent,
                ),
              ),
              SizedBox(height: compact ? ZapSpacing.md : ZapSpacing.lg),
              Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 15 : 18,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (tip) ...[
                const SizedBox(height: ZapSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md,
                    vertical: ZapSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: ZapColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZapColors.info.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: ZapColors.info),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Tip: Check your WiFi or mobile data',
                          style: TextStyle(
                            color: ZapColors.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (onRetry != null) ...[
                SizedBox(
                  height: compact ? ZapSpacing.lg : ZapSpacing.xl,
                ),
                Semantics(
                  label: 'Retry',
                  button: true,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Retry'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(
                        compact ? 160 : double.infinity,
                        ZapSpacing.buttonHeight,
                      ),
                      backgroundColor: ZapColors.safe,
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

/// Inline strip for list/card errors (smaller footprint).
class ZapErrorInline extends StatelessWidget {
  final ZapErrorKind kind;
  final VoidCallback? onRetry;

  const ZapErrorInline({
    super.key,
    required this.kind,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ZapErrorMapper.accent(kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(ZapErrorMapper.icon(kind), color: accent, size: 22),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Text(
              ZapErrorMapper.title(kind),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (onRetry != null)
            Semantics(
              label: 'Retry',
              button: true,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
        ],
      ),
    );
  }
}
