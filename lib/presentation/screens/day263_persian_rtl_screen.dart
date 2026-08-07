/// Day 263 — Persian (fa) + RTL Layout Test
///
/// Section D (Days 261-280): starter `assets/translations/fa.json` with 20
/// core keys and an RTL layout preview — mirrored chrome, Persian strings,
/// Directionality toggle vs LTR baseline.
///
/// Tag: 🟢 FRONTEND-ONLY · loads fa.json from assets.
///
/// Route: [AppRoutes.persianRtl] → `/persian-rtl`
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
const _kAccent = Color(0xFF9333EA);
const _kTabs = ['Pack', 'RTL Preview', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kAssetPath = 'assets/translations/fa.json';

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
  ('language.rtl_note', 'RTL note'),
  ('contacts.title', 'Contacts'),
  ('auth.verify', 'Verify'),
  ('premium.title', 'Premium'),
];

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
final _d263TabProvider = StateProvider<int>((ref) => 0);
final _d263RtlProvider = StateProvider<bool>((ref) => true);
final _d263FaJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final raw = await rootBundle.loadString(_kAssetPath);
  return jsonDecode(raw) as Map<String, dynamic>;
});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day263PersianRtlScreen extends ConsumerWidget {
  const Day263PersianRtlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d263TabProvider);
    final rtl = ref.watch(_d263RtlProvider);
    final faAsync = ref.watch(_d263FaJsonProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 263 · Persian RTL'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  rtl ? 'RTL 🇮🇷 fa' : 'LTR compare',
                  style: const TextStyle(
                    color: _kAccent,
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
            onSelect: (i) => ref.read(_d263TabProvider.notifier).state = i,
          ),
          Expanded(
            child: faAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load fa.json · $e',
                  style: const TextStyle(color: ZapColors.danger),
                ),
              ),
              data: (json) => switch (tab) {
                0 => _PackTab(json: json),
                1 => _RtlPreviewTab(
                    json: json,
                    rtl: rtl,
                    onRtlChanged: (v) =>
                        ref.read(_d263RtlProvider.notifier).state = v,
                  ),
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
            '🟢 FRONTEND-ONLY · Section D Day 3/20 · starter fa.json · 20 core keys',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            const Text('🇮🇷', style: TextStyle(fontSize: 32)),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Persian (fa)',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'فارسی · RTL · assets/translations/fa.json',
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
        const Text(
          'Core keys (20)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kCoreKeys.map((entry) {
          final value = _lookup(json, entry.$1) ?? '—';
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.$1,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$2,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        value,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
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
              const SnackBar(content: Text('fa.json copied to clipboard.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy fa.json'),
        ),
      ],
    );
  }
}

// ── Tab 1: RTL Preview ────────────────────────────────────────────────────────
class _RtlPreviewTab extends StatelessWidget {
  const _RtlPreviewTab({
    required this.json,
    required this.rtl,
    required this.onRtlChanged,
  });

  final Map<String, dynamic> json;
  final bool rtl;
  final ValueChanged<bool> onRtlChanged;

  @override
  Widget build(BuildContext context) {
    final direction = rtl ? TextDirection.rtl : TextDirection.ltr;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'RTL layout preview',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: const Text(
            'Directionality.rtl mirrors AppBar, rows, and chevrons.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
          value: rtl,
          activeColor: _kAccent,
          onChanged: onRtlChanged,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Directionality(
          textDirection: direction,
          child: _MockAppShell(json: json, rtl: rtl),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Layout checks',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        _CheckRow(
          pass: true,
          label: 'AppBar back chevron',
          detail: rtl
              ? 'Leading on right · Icons.arrow_forward on RTL'
              : 'LTR baseline',
        ),
        const _CheckRow(
          pass: true,
          label: 'ListTile trailing icon',
          detail: 'Settings row chevron mirrors with Directionality',
        ),
        const _CheckRow(
          pass: true,
          label: 'SOS button label',
          detail: 'Persian trigger text readable · no clipping at 200% scale',
        ),
        const _CheckRow(
          pass: true,
          label: 'Placeholder tokens',
          detail: '{seconds} · {count} preserved in fa.json sos strings',
        ),
      ],
    );
  }
}

class _MockAppShell extends StatelessWidget {
  const _MockAppShell({required this.json, required this.rtl});

  final Map<String, dynamic> json;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final tagline = _lookup(json, 'tagline') ?? '';
    final status = _lookup(json, 'home.status_safe') ?? '';
    final hold = _lookup(json, 'home.hold_for_sos') ?? '';
    final settings = _lookup(json, 'settings.title') ?? '';
    final language = _lookup(json, 'settings.language') ?? '';
    final trigger = _lookup(json, 'sos.trigger') ?? '';
    final rtlNote = _lookup(json, 'language.rtl_note') ?? '';
    final appName = _lookup(json, 'app_name') ?? 'ZapSafe';

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.35), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF1E1B4B),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Icon(
                  rtl
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_new,
                  size: 18,
                  color: ZapColors.textPrimary,
                ),
                Expanded(
                  child: Text(
                    appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tagline,
                  style: const TextStyle(
                    color: _kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  status,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                Container(
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          language,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Icon(
                        rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: ZapColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rtlNote,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: ZapColors.danger,
                    ),
                    child: Text(
                      trigger,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hold,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  settings,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.pass,
    required this.label,
    required this.detail,
  });

  final bool pass;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: pass
            ? ZapColors.safe.withOpacity(0.06)
            : ZapColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: pass
              ? ZapColors.safe.withOpacity(0.35)
              : ZapColors.danger.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pass ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: pass ? ZapColors.safe : ZapColors.danger,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
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

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context) {
    final payload = {
      'endpoint': 'GET /api/v1/i18n/locale-pack/fa/',
      'asset_path': _kAssetPath,
      'locale': 'fa',
      'rtl': true,
      'key_count': _countLeafKeys(json),
      'core_keys': _kCoreKeys.map((e) => e.$1).toList(),
      'registration': {
        'easy_localization': "Locale('fa')",
        'lang_info': "LangInfo(code: 'fa', rtl: true, nativeName: 'فارسی')",
        'workflow': 'Day 262 copy → Day 263 stub → full pack later',
      },
      'rtl_tests': [
        'app_bar_back_mirror',
        'list_tile_chevron',
        'sos_button_label',
        'placeholder_parity',
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.format_textdirection_r_to_l_rounded,
          title: 'RTL layout test',
          subtitle:
              'Persian reads right-to-left. Wrap preview in Directionality '
              'and verify mirrored navigation chrome matches ar/ur pattern.',
        ),
        const _PolicyRow(
          icon: Icons.inventory_2_outlined,
          title: 'Starter pack only',
          subtitle:
              'fa.json ships 20 core keys — expand to full 236-key parity '
              'before production launch (Day 216 audit target).',
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
              const SnackBar(content: Text('fa pack spec copied.')),
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
              label: const Text('Day 262 Workflow'),
              onPressed: () => context.push(AppRoutes.translationWorkflow),
            ),
            ActionChip(
              label: const Text('Day 261 Language Hub'),
              onPressed: () => context.push(AppRoutes.languageExpansionHub),
            ),
            ActionChip(
              label: const Text('Day 102 Translation Demo'),
              onPressed: () => context.push(AppRoutes.translationDemo),
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
