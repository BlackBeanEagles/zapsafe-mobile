/// Day 210 — Error States Sweep
///
/// Section A (Days 201-220): friendly error UI via [ZapErrorState] —
/// plain language, Retry, connection tip. Never show DioException to users.
///
/// Tag: 🟣 POLISH — ships [zap_error_state.dart] widget library.
///
/// Route: [AppRoutes.errorStates] → `/error-states`
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/zap_error_state.dart';

// ── Demo error variants ───────────────────────────────────────────────────────
class _ErrorVariant {
  final String id;
  final String label;
  final ZapErrorKind kind;
  final Object mockException;
  final String rawDevOnly;

  const _ErrorVariant({
    required this.id,
    required this.label,
    required this.kind,
    required this.mockException,
    required this.rawDevOnly,
  });
}

List<_ErrorVariant> _buildVariants() => [
  _ErrorVariant(
    id: 'network',
    label: 'Network offline',
    kind: ZapErrorKind.network,
    mockException: DioException(
      requestOptions: RequestOptions(path: '/api/v1/protection-score/'),
      type: DioExceptionType.connectionError,
    ),
    rawDevOnly: 'DioException [connection error]: Failed host lookup',
  ),
  _ErrorVariant(
    id: 'forbidden',
    label: '403 Forbidden',
    kind: ZapErrorKind.forbidden,
    mockException: DioException(
      requestOptions: RequestOptions(path: '/api/v1/vault/'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/vault/'),
        statusCode: 403,
      ),
    ),
    rawDevOnly: 'DioException [bad response]: 403 Forbidden',
  ),
  _ErrorVariant(
    id: 'server',
    label: '500 Server error',
    kind: ZapErrorKind.server,
    mockException: DioException(
      requestOptions: RequestOptions(path: '/api/v1/sos/'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/sos/'),
        statusCode: 500,
      ),
    ),
    rawDevOnly: 'DioException [bad response]: 500 Internal Server Error',
  ),
  _ErrorVariant(
    id: 'timeout',
    label: 'Timeout',
    kind: ZapErrorKind.timeout,
    mockException: DioException(
      requestOptions: RequestOptions(path: '/api/v1/contacts/'),
      type: DioExceptionType.receiveTimeout,
    ),
    rawDevOnly: 'DioException [receive timeout]: 30000ms exceeded',
  ),
];

final _kVariants = _buildVariants();

// ── Providers ─────────────────────────────────────────────────────────────────
final _d210TabProvider = StateProvider<int>((ref) => 0);
final _d210VariantProvider = StateProvider<int>((ref) => 0);
final _d210CompactProvider = StateProvider<bool>((ref) => false);
final _d210RetryCountProvider = StateProvider<int>((ref) => 0);
final _d210ShowRawProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Live Preview', 'Variants', 'Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day210ErrorStatesScreen extends ConsumerWidget {
  const Day210ErrorStatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d210TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 210 · Error States'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d210TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LivePreviewTab(),
              1 => const _VariantsTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Preview ───────────────────────────────────────────────────────
class _LivePreviewTab extends ConsumerWidget {
  const _LivePreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_d210VariantProvider);
    final compact = ref.watch(_d210CompactProvider);
    final retryCount = ref.watch(_d210RetryCountProvider);
    final showRaw = ref.watch(_d210ShowRawProvider);
    final variant = _kVariants[index];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 10/20 · Never show DioException to users',
            style: TextStyle(color: ZapColors.danger, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          variant.label,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          constraints: const BoxConstraints(minHeight: 280),
          width: double.infinity,
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: ZapErrorState.fromError(
            error: variant.mockException,
            compact: compact,
            onRetry: () {
              ref.read(_d210RetryCountProvider.notifier).state = retryCount + 1;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Retry tapped (${retryCount + 1}) — would ref.invalidate(provider)',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        SwitchListTile(
          value: compact,
          onChanged: (v) => ref.read(_d210CompactProvider.notifier).state = v,
          activeColor: ZapColors.info,
          title: const Text(
            'Compact mode',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          subtitle: const Text(
            'For inline list errors',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What the user sees vs dev logs',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                'User: ${ZapErrorMapper.title(variant.kind)}',
                style: const TextStyle(color: ZapColors.safe, fontSize: 12),
              ),
              const SizedBox(height: ZapSpacing.xs),
              GestureDetector(
                onTap: () => ref.read(_d210ShowRawProvider.notifier).state =
                    !showRaw,
                child: Text(
                  showRaw
                      ? 'Dev only (hidden from UI): ${variant.rawDevOnly}'
                      : 'Tap to reveal raw DioException (dev only — never ship to UI)',
                  style: TextStyle(
                    color: showRaw ? ZapColors.danger : ZapColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Inline variant',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapErrorInline(
          kind: variant.kind,
          onRetry: () {},
        ),
      ],
    );
  }
}

// ── Tab 1: Variants ───────────────────────────────────────────────────────────
class _VariantsTab extends ConsumerWidget {
  const _VariantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d210VariantProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          '4 standard error variants',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'ZapErrorMapper.kindFrom(error) picks the right copy automatically.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...List.generate(_kVariants.length, (i) {
          final v = _kVariants[i];
          final isSelected = selected == i;
          final accent = ZapErrorMapper.accent(v.kind);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? accent : ZapColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              leading: Icon(ZapErrorMapper.icon(v.kind), color: accent),
              title: Text(
                v.label,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                ZapErrorMapper.message(v.kind),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: accent)
                  : null,
              onTap: () => ref.read(_d210VariantProvider.notifier).state = i,
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy ZapErrorState.fromError usage',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text:
                      'error: (e, _) => ZapErrorState.fromError(\n'
                      '  error: e,\n'
                      '  onRetry: () => ref.invalidate(myProvider),\n'
                      ')',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Riverpod pattern copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy Riverpod pattern'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const adopt = [
      ('Day 59 Protection Score', '_ErrorState → ZapErrorState'),
      ('Day 58 Safe Zones', '_ListError → ZapErrorInline'),
      ('Day 60 Drill History', '_HistoryError → ZapErrorState'),
      ('Day 57 ML Analytics', '_ErrorState → ZapErrorState'),
      ('Day 88 Notification History', 'inline retry → ZapErrorInline'),
      ('Day 82 Evidence Vault', 'add error branch to async provider'),
      ('Day 83 Contacts v2', 'list fetch errors'),
      ('Day 207 Live Chat', 'send failure already has Retry chip'),
    ];

    const rules = [
      ('Never show', 'DioException, stack traces, HTTP codes in UI'),
      ('Always show', 'Plain title + helpful message + Retry'),
      ('Connection tip', 'Network + timeout variants only'),
      ('Dev logging', 'Sentry/console gets full error; UI gets ZapErrorMapper'),
      ('Compact mode', 'ZapErrorInline for list rows'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Error states sweep (Day 210 polish)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Rules',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...rules.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    r.$1,
                    style: const TextStyle(
                      color: ZapColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Screens to adopt',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...adopt.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: ZapColors.textMuted),
                const SizedBox(width: ZapSpacing.xs),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${a.$1}\n',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: a.$2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Widget: lib/presentation/widgets/zap_error_state.dart\n'
          '• ZapErrorKind — network / forbidden / server / timeout / generic\n'
          '• ZapErrorMapper — kindFrom(error) + user-safe copy\n'
          '• ZapErrorState — full placeholder with Retry\n'
          '• ZapErrorInline — compact list-row variant',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 213 — Animation polish pass (SOS breathe, mode badge morph).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.danger : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
