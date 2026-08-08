/// Day 266 — Japanese (ja) Translation Pack
///
/// Section D (Days 261-280): starter `assets/translations/ja.json` with 20
/// core keys, bilingual review table (en ↔ ja), per-key QA checkboxes,
/// and LTR in-app preview mock.
///
/// Tag: 🟢 FRONTEND-ONLY · loads ja.json from assets.
///
/// Route: [AppRoutes.japanesePack] → `/japanese-pack`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFBE123C);
const _kTabs = ['Pack', 'Review', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kAssetPath = 'assets/translations/ja.json';

const _kCoreKeys = [
  ('app_name', 'App name'),
  ('tagline', 'Tagline'),
  ('common.save', 'Save'),
  ('common.cancel', 'Cancel'),
  ('common.back', 'Back'),
  ('common.done', 'Done'),
  ('sos.trigger', 'SOS trigger'),
  ('sos.countdown', 'SOS countdown'),
  ('sos.active', 'SOS active'),
  ('sos.cancel', 'Cancel SOS'),
  ('sos.sent', 'Alert sent'),
  ('home.status_safe', 'Safe status'),
  ('home.hold_for_sos', 'Hold for SOS'),
  ('settings.title', 'Settings'),
  ('settings.language', 'Language'),
  ('language.select', 'Select language'),
  ('language.rtl_note', 'Reading direction note'),
  ('contacts.title', 'Contacts'),
  ('auth.verify', 'Verify'),
  ('premium.title', 'Premium'),
];

const _kEnReference = {
  'app_name': 'ZapSafe',
  'tagline': 'Safety in your hands',
  'common.save': 'Save',
  'common.cancel': 'Cancel',
  'common.back': 'Back',
  'common.done': 'Done',
  'sos.trigger': 'TRIGGER SOS',
  'sos.countdown': 'SOS in {seconds}s',
  'sos.active': 'SOS ACTIVE',
  'sos.cancel': 'Cancel SOS',
  'sos.sent': 'Alert sent to {count} contacts',
  'home.status_safe': 'You are safe',
  'home.hold_for_sos': 'Press & hold for SOS',
  'settings.title': 'Settings',
  'settings.language': 'Language',
  'language.select': 'Select Language',
  'language.rtl_note': 'This language reads left-to-right',
  'contacts.title': 'Emergency Contacts',
  'auth.verify': 'Verify',
  'premium.title': 'Upgrade to Premium',
};

String? _lookup(Map<String, dynamic> json, String path) {
  final parts = path.split('.');
  dynamic cur = json;
  for (final part in parts) {
    if (cur is! Map<String, dynamic>) return null;
    cur = cur[part];
  }
  return cur?.toString();
}

int _countLeafKeys(Map<String, dynamic> json) {
  var count = 0;
  void walk(dynamic node) {
    if (node is Map<String, dynamic>) {
      for (final v in node.values) {
        if (v is Map) {
          walk(v);
        } else {
          count++;
        }
      }
    }
  }

  walk(json);
  return count;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d266TabProvider = StateProvider<int>((ref) => 0);
final _d266JaJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final raw = await rootBundle.loadString(_kAssetPath);
  return jsonDecode(raw) as Map<String, dynamic>;
});
final _d266ReviewedProvider = StateProvider<Set<String>>((ref) => {});
final _d266ApprovedProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day266JapanesePackScreen extends ConsumerWidget {
  const Day266JapanesePackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d266TabProvider);
    final reviewed = ref.watch(_d266ReviewedProvider);
    final approved = ref.watch(_d266ApprovedProvider);
    final jaAsync = ref.watch(_d266JaJsonProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 266 · Japanese Pack'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (approved ? ZapColors.safe : _kAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (approved ? ZapColors.safe : _kAccent)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  approved
                      ? 'APPROVED ✅'
                      : '${reviewed.length}/${_kCoreKeys.length}',
                  style: TextStyle(
                    color: approved ? ZapColors.safe : _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d266TabProvider.notifier).state = i,
          ),
          Expanded(
            child: jaAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load ja.json · $e',
                  style: const TextStyle(color: ZapColors.danger),
                ),
              ),
              data: (json) => switch (tab) {
                0 => _PackTab(json: json),
                1 => _ReviewTab(json: json),
                _ => _InfoTab(json: json),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Pack ───────────────────────────────────────────────────────────────
class _PackTab extends StatelessWidget {
  const _PackTab({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context) {
    final keyCount = _countLeafKeys(json);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section D Day 6/20 · starter ja.json · LTR locale',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            const Text('🇯🇵', style: TextStyle(fontSize: 32)),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Japanese (ja)',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '日本語 · assets/translations/ja.json',
                    style: TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ZapColors.safe.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
              ),
              child: Text(
                '$keyCount keys',
                style: const TextStyle(
                  color: ZapColors.safe,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        _MockPreview(json: json),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(json),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 9,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(json)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ja.json copied to clipboard.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy ja.json'),
        ),
      ],
    );
  }
}

class _MockPreview extends StatelessWidget {
  const _MockPreview({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context) {
    final tagline = _lookup(json, 'tagline') ?? '';
    final status = _lookup(json, 'home.status_safe') ?? '';
    final trigger = _lookup(json, 'sos.trigger') ?? '';
    final settings = _lookup(json, 'settings.title') ?? '';

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LTR preview',
            style: TextStyle(
              color: _kAccent,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            tagline,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          Text(
            status,
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: ZapSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(backgroundColor: ZapColors.danger),
              child: Text(trigger),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            settings,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Review ─────────────────────────────────────────────────────────────
class _ReviewTab extends ConsumerWidget {
  const _ReviewTab({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed = ref.watch(_d266ReviewedProvider);
    final approved = ref.watch(_d266ApprovedProvider);
    final allDone = reviewed.length == _kCoreKeys.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        LinearProgressIndicator(
          value: reviewed.length / _kCoreKeys.length,
          minHeight: 8,
          backgroundColor: ZapColors.border,
          color: allDone ? ZapColors.safe : _kAccent,
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          '${reviewed.length}/${_kCoreKeys.length} keys reviewed · '
          '${allDone ? 'ready to approve' : 'QA in progress'}',
          style: TextStyle(
            color: allDone ? ZapColors.safe : ZapColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kCoreKeys.map((entry) {
          final key = entry.$1;
          final jaVal = _lookup(json, key) ?? '—';
          final enVal = _kEnReference[key] ?? '—';
          final done = reviewed.contains(key);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: done
                  ? ZapColors.safe.withOpacity(0.06)
                  : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: done
                    ? ZapColors.safe.withOpacity(0.35)
                    : ZapColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: done,
                      activeColor: ZapColors.safe,
                      onChanged: approved
                          ? null
                          : (v) {
                              final next = {...reviewed};
                              if (v == true) {
                                next.add(key);
                              } else {
                                next.remove(key);
                              }
                              ref
                                  .read(_d266ReviewedProvider.notifier)
                                  .state = next;
                              ref.read(_d266ApprovedProvider.notifier).state =
                                  false;
                            },
                    ),
                    Expanded(
                      child: Text(
                        key,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Text(
                      entry.$2,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'en · $enVal',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ja · $jaVal',
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: !allDone || approved
              ? null
              : () {
                  ref.read(_d266ApprovedProvider.notifier).state = true;
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Japanese pack approved (mock) · ready for EasyLocalization',
                      ),
                    ),
                  );
                },
          icon: Icon(approved ? Icons.verified_rounded : Icons.check_rounded),
          label: Text(approved ? 'Pack approved' : 'Approve pack (mock)'),
          style: FilledButton.styleFrom(
            backgroundColor: ZapColors.safe,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        if (!allDone)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                ref.read(_d266ReviewedProvider.notifier).state = {
                  for (final k in _kCoreKeys) k.$1,
                };
              },
              child: const Text('Mark all reviewed'),
            ),
          ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed = ref.watch(_d266ReviewedProvider);
    final approved = ref.watch(_d266ApprovedProvider);

    final payload = {
      'endpoint': 'GET /api/v1/i18n/locale-pack/ja/',
      'asset_path': _kAssetPath,
      'locale': 'ja',
      'rtl': false,
      'key_count': _countLeafKeys(json),
      'reviewed_count': reviewed.length,
      'approved': approved,
      'core_keys': _kCoreKeys.map((e) => e.$1).toList(),
      'registration': {
        'easy_localization': "Locale('ja')",
        'lang_info':
            "LangInfo(code: 'ja', nativeName: '日本語', flag: '🇯🇵')",
        'workflow': 'Day 262 template → Day 266 ja pack → expand to 236 keys',
      },
      'qa_checks': [
        'placeholder_parity',
        'native_speaker_review',
        'sos_string_length',
        'lrt_layout_smoke',
        'cjk_line_break',
        'font_fallback_smoke',
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.translate_rounded,
          title: 'Japan expansion pack',
          subtitle:
              'Starter ja.json mirrors Day 265 vi structure · 20 core keys '
              'for SOS, home, settings — expand before launch.',
        ),
        const _PolicyRow(
          icon: Icons.fact_check_rounded,
          title: 'Pack review UI',
          subtitle:
              'Bilingual en/ja table with per-key QA checkboxes · mock approve '
              'gate when all 20 keys reviewed.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ja pack spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy pack spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 265 Vietnamese Pack'),
              onPressed: () => context.push(AppRoutes.vietnamesePack),
            ),
            ActionChip(
              label: const Text('Day 264 Indonesian Pack'),
              onPressed: () => context.push(AppRoutes.indonesianPack),
            ),
            ActionChip(
              label: const Text('Day 263 Persian RTL'),
              onPressed: () => context.push(AppRoutes.persianRtl),
            ),
            ActionChip(
              label: const Text('Day 262 Workflow'),
              onPressed: () => context.push(AppRoutes.translationWorkflow),
            ),
            ActionChip(
              label: const Text('Day 261 Language Hub'),
              onPressed: () => context.push(AppRoutes.languageExpansionHub),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
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
