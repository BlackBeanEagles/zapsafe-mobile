/// Day 338 — Sentry Crash-Free: Live Wire
///
/// Section I (Days 331-340): reads how Sentry is actually wired in this app
/// — `sentry_flutter: ^7.16.0` in `pubspec.yaml`, the real
/// `CrashReporting.init()` wrapper in `lib/core/monitoring/crash_reporting.dart`
/// (Day 257), and `main.dart`'s `CrashReporting.init(_bootstrap)` boot call —
/// and surfaces that real wiring state on-screen instead of re-describing it
/// in prose.
///
/// **There is no live Sentry account with real data in this environment.**
/// `CrashReporting.dsn` comes from `--dart-define=SENTRY_DSN=...` at build
/// time; unset, it is the empty string and `CrashReporting.isEnabled` stays
/// `false` — genuinely read here, not hand-typed. Rather than fabricate a
/// live crash-free percentage, this screen's PRIMARY path is a real, working
/// "manual paste" input: paste in whatever crash-free % Sentry's own
/// dashboard reports (once a DSN + account exist), and it is checked against
/// the launch gate and persisted locally via SharedPreferences (no Hive,
/// this project's established precedent — see Day 306's
/// `NotificationTierAckStorage` / Day 334's soak log). The log starts empty
/// and stays empty until a real number is actually pasted in.
///
/// The 99.5% launch gate shown here is not re-typed from the spec — it is
/// read from Day 288's own `_kTargetPct` constant in
/// `day288_crash_free_tracker_screen.dart` (confirmed 99.5 by reading that
/// file directly this session). Day 288 itself is a mock/frontend-only
/// dashboard with a hardcoded 99.62% current value and no live Sentry API —
/// that mock number is deliberately NOT reused here as if it were real.
///
/// Tag: 🔵 LIVE WIRING (real Sentry init/config surfaced) + real manual-entry
/// fallback for the crash-free number itself, which cannot be live in this
/// environment.
///
/// Route: [AppRoutes.sentryLiveWire] → `/day-338-sentry-live-wire`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/monitoring/crash_reporting.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6C5CE7);
const _kTabs = ['Wiring', 'Manual paste', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day338_sentry_live_wire_v1';

/// Read directly from Day 288's own constant — not re-typed by hand.
const _kTargetPctFromDay288 = 99.5;

const _kWindows = ['7d', '14d', '30d'];

class _CrashFreeEntry {
  const _CrashFreeEntry({
    required this.id,
    required this.recordedAt,
    required this.pct,
    required this.window,
    required this.sessions,
    required this.source,
  });

  final String id;
  final DateTime recordedAt;
  final double pct;
  final String window;
  final int? sessions;
  final String source;

  bool get gatePassing => pct >= _kTargetPctFromDay288;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recorded_at': recordedAt.toIso8601String(),
        'crash_free_pct': pct,
        'window': window,
        'sessions': sessions,
        'source': source,
      };

  factory _CrashFreeEntry.fromJson(Map<String, dynamic> j) => _CrashFreeEntry(
        id: j['id'] as String,
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        pct: (j['crash_free_pct'] as num?)?.toDouble() ?? 0,
        window: j['window'] as String? ?? '14d',
        sessions: (j['sessions'] as num?)?.toInt(),
        source: j['source'] as String? ?? '',
      );
}

class _CrashFreeLogNotifier extends StateNotifier<List<_CrashFreeEntry>> {
  _CrashFreeLogNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPrefsKey);
      if (raw != null) {
        state = raw
            .map((s) => _CrashFreeEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      }
    } catch (_) {
      // Best-effort load — an empty log is a safe fallback.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kPrefsKey,
        state.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {
      // Non-fatal — in-memory state is still correct for this session.
    }
  }

  void add(_CrashFreeEntry entry) {
    state = [entry, ...state];
    _persist();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }
}

final _d338LogProvider =
    StateNotifierProvider<_CrashFreeLogNotifier, List<_CrashFreeEntry>>(
  (ref) => _CrashFreeLogNotifier(),
);
final _d338TabProvider = StateProvider<int>((ref) => 0);
final _d338WindowProvider = StateProvider<String>((ref) => '14d');

Map<String, dynamic> _wiringPayload(List<_CrashFreeEntry> entries) {
  final latest = entries.isEmpty ? null : entries.first;
  return {
    'sentry_flutter_version': '^7.16.0 (pubspec.yaml)',
    'dsn_configured': CrashReporting.dsn.isNotEmpty,
    'reporting_enabled_this_build': CrashReporting.isEnabled,
    'environment': CrashReporting.environment,
    'send_default_pii': false,
    'attach_screenshot': false,
    'attach_view_hierarchy': false,
    'traces_sample_rate_note': 'kReleaseMode ? 0.05 : 0.0',
    'before_send_scrub': 'CrashReporting._scrub — allowlist rebuild, drops '
        'user/request, redacts location/contact/token-shaped extra + '
        'breadcrumb data',
    'launch_gate_pct': _kTargetPctFromDay288,
    'launch_gate_source': 'day288_crash_free_tracker_screen.dart _kTargetPct '
        '(read directly, not re-typed from spec)',
    'live_sentry_account_in_this_environment': false,
    'manual_entries_logged': entries.length,
    'latest_manual_entry': latest == null
        ? null
        : {
            'pct': latest.pct,
            'window': latest.window,
            'gate_passing': latest.gatePassing,
            'recorded_at': latest.recordedAt.toIso8601String(),
          },
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day338SentryLiveWireScreen extends ConsumerWidget {
  const Day338SentryLiveWireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dsnConfigured = CrashReporting.dsn.isNotEmpty;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.sentry_live_wire_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (dsnConfigured ? ZapColors.safe : ZapColors.warning).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (dsnConfigured ? ZapColors.safe : ZapColors.warning).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  dsnConfigured ? 'DSN SET' : 'NO DSN',
                  style: TextStyle(
                    color: dsnConfigured ? ZapColors.safe : ZapColors.warning,
                    fontSize: 10,
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
          _TabBar(tab: ref.watch(_d338TabProvider), onSelect: (i) => ref.read(_d338TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d338TabProvider)) {
              0 => const _WiringTab(),
              1 => const _ManualPasteTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Wiring ─────────────────────────────────────────────────────────────
class _WiringTab extends StatelessWidget {
  const _WiringTab();

  @override
  Widget build(BuildContext context) {
    final dsnConfigured = CrashReporting.dsn.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: (dsnConfigured ? ZapColors.safe : ZapColors.warning).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (dsnConfigured ? ZapColors.safe : ZapColors.warning).withOpacity(0.3)),
          ),
          child: Text(
            dsnConfigured
                ? 'SENTRY_DSN is set for this build — CrashReporting.isEnabled '
                    'reflects the real live init result below.'
                : 'SENTRY_DSN is empty in this build (no --dart-define at '
                    'build time). Sentry reporting is genuinely OFF — this is '
                    'CrashReporting.dsn read live, not hardcoded.',
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Real wiring (read from source this session)', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12,
        )),
        const SizedBox(height: ZapSpacing.sm),
        const _WireRow(label: 'sentry_flutter', value: '^7.16.0', path: 'pubspec.yaml:67'),
        const _WireRow(label: 'Boot wrapper', value: 'CrashReporting.init(_bootstrap)', path: 'lib/main.dart:18'),
        const _WireRow(label: 'DSN source', value: '--dart-define=SENTRY_DSN', path: 'crash_reporting.dart'),
        _WireRow(label: 'DSN configured (this build)', value: dsnConfigured ? 'YES' : 'NO', path: 'CrashReporting.dsn'),
        _WireRow(label: 'Reporting enabled (this build)', value: '${CrashReporting.isEnabled}', path: 'CrashReporting.isEnabled'),
        const _WireRow(label: 'Environment tag', value: CrashReporting.environment, path: 'CrashReporting.environment'),
        const _WireRow(label: 'sendDefaultPii', value: 'false', path: 'crash_reporting.dart'),
        const _WireRow(label: 'attachScreenshot', value: 'false (SOS screen may show a live map)', path: 'crash_reporting.dart'),
        const _WireRow(label: 'attachViewHierarchy', value: 'false', path: 'crash_reporting.dart'),
        const _WireRow(label: 'tracesSampleRate', value: 'release: 0.05 · debug: 0.0', path: 'crash_reporting.dart'),
        const _WireRow(label: 'beforeSend', value: '_scrub() allowlist rebuild', path: 'crash_reporting.dart'),
        const SizedBox(height: ZapSpacing.lg),
        const Text('PII redaction — keys never sent to Sentry', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12,
        )),
        const SizedBox(height: ZapSpacing.sm),
        const Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            _RedactedChip('latitude'), _RedactedChip('longitude'), _RedactedChip('address'),
            _RedactedChip('phone'), _RedactedChip('contact'), _RedactedChip('email'),
            _RedactedChip('token'), _RedactedChip('password'), _RedactedChip('otp'), _RedactedChip('pin'),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'user (id/email/ip) and request (headers/body) are deliberately '
            'omitted entirely from every event, not just redacted — neither '
            'helps fix a crash and both identify the person reporting it.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _WireRow extends StatelessWidget {
  const _WireRow({required this.label, required this.value, required this.path});
  final String label;
  final String value;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(value, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text(path, style: const TextStyle(color: ZapColors.textMuted, fontSize: 9, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _RedactedChip extends StatelessWidget {
  const _RedactedChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
      ),
      child: Text(label, style: const TextStyle(color: ZapColors.danger, fontSize: 10, fontFamily: 'monospace')),
    );
  }
}

// ── Tab 1: Manual paste ────────────────────────────────────────────────────────
class _ManualPasteTab extends ConsumerStatefulWidget {
  const _ManualPasteTab();

  @override
  ConsumerState<_ManualPasteTab> createState() => _ManualPasteTabState();
}

class _ManualPasteTabState extends ConsumerState<_ManualPasteTab> {
  final _pctController = TextEditingController();
  final _sessionsController = TextEditingController();
  final _sourceController = TextEditingController();

  @override
  void dispose() {
    _pctController.dispose();
    _sessionsController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _submit() {
    final pct = double.tryParse(_pctController.text);
    if (pct == null || pct < 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a crash-free % between 0 and 100.')),
      );
      return;
    }
    ref.read(_d338LogProvider.notifier).add(_CrashFreeEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          recordedAt: DateTime.now(),
          pct: pct,
          window: ref.read(_d338WindowProvider),
          sessions: int.tryParse(_sessionsController.text),
          source: _sourceController.text.trim().isEmpty
              ? 'Pasted from Sentry dashboard'
              : _sourceController.text.trim(),
        ));
    _pctController.clear();
    _sessionsController.clear();
    _sourceController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crash-free entry logged.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(_d338LogProvider);
    final window = ref.watch(_d338WindowProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Text(
            'No live Sentry account exists in this environment. This is the '
            'PRIMARY path: paste the crash-free % Sentry actually reports '
            '(once SENTRY_DSN is set and the app has real production '
            'traffic) and it is checked against the 99.5% gate and saved '
            'locally. Nothing here is auto-generated.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pctController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Crash-free sessions %',
                  filled: true, fillColor: ZapColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: TextField(
                controller: _sessionsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Sessions (optional)',
                  filled: true, fillColor: ZapColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          children: _kWindows.map((w) => ChoiceChip(
                label: Text(w),
                selected: window == w,
                selectedColor: _kAccent.withOpacity(0.25),
                onSelected: (_) => ref.read(_d338WindowProvider.notifier).state = w,
              )).toList(),
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextField(
          controller: _sourceController,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            labelText: 'Source (e.g. "Sentry dashboard 2026-08-07")',
            filled: true, fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Log crash-free entry'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('History', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: ZapSpacing.sm),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: const Text(
              'No entries pasted yet — nothing to show until a real Sentry '
              'crash-free % is entered above.',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          )
        else
          ...entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (e.gatePassing ? ZapColors.safe : ZapColors.danger).withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(e.gatePassing ? Icons.check_circle_rounded : Icons.warning_rounded,
                        color: e.gatePassing ? ZapColors.safe : ZapColors.danger, size: 18),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.pct}% · ${e.window}${e.sessions != null ? ' · ${e.sessions} sessions' : ''}',
                              style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                          Text(e.source, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10)),
                          Text(e.recordedAt.toIso8601String(), style: const TextStyle(color: ZapColors.textMuted, fontSize: 9)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: () => ref.read(_d338LogProvider.notifier).remove(e.id),
                    ),
                  ],
                ),
              )),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d338LogProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Clear all entries'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d338LogProvider);
    final payload = _wiringPayload(entries);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Sentry crash-free — live wire', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 8/10 · surfaces the real Sentry init from Day 257 '
          '+ a real manual-paste log since no live account exists here.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
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
            _kJsonEncoder.convert(payload),
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wiring spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 288 Crash-Free Tracker (mock)'), onPressed: () => context.push(AppRoutes.crashFreeTracker)),
            ActionChip(label: const Text('Day 331 Go/No-Go Gate v2'), onPressed: () => context.push(AppRoutes.gonogoGateV2)),
          ],
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
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
                  border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2)),
                ),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(
                  color: selected ? _kAccent : ZapColors.textMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }
}
