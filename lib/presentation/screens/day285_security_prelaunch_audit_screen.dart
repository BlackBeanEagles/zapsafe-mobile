/// Day 285 — Security Pre-Launch Audit Checklist
///
/// Section E (Days 281-300): OWASP MASVS L2 pre-launch checklist mapped to
/// Section C security work (Days 181-190).
///
/// Tag: 🟢 FRONTEND-ONLY · on-device checklist · no external audit API.
///
/// Route: [AppRoutes.securityPrelaunchAudit] → `/security-prelaunch-audit`
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
const _kAccent = Color(0xFF10B981);
const _kTabs = ['Checklist', 'Progress', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _AuditStatus { pass, warn, fail, unchecked }

class _MasvsItem {
  const _MasvsItem({
    required this.id,
    required this.category,
    required this.code,
    required this.title,
    required this.detail,
    required this.dayLink,
    required this.route,
    required this.defaultStatus,
  });

  final String id;
  final String category;
  final String code;
  final String title;
  final String detail;
  final String dayLink;
  final String route;
  final _AuditStatus defaultStatus;
}

const _kMasvsItems = [
  _MasvsItem(
    id: 'mstg_network_1',
    category: 'Network',
    code: 'MSTG-NETWORK-1',
    title: 'TLS certificate pinning',
    detail: 'api.zapsafe.app + exports.zapsafe.app SPKI pins active.',
    dayLink: 'Day 181',
    route: AppRoutes.certPinning,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_network_2',
    category: 'Network',
    code: 'MSTG-NETWORK-2',
    title: 'NSC + ATS cleartext blocked',
    detail: 'Android NSC + iOS ATS — no HTTP fallback on release.',
    dayLink: 'Day 182',
    route: AppRoutes.networkSecurity,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_auth_1',
    category: 'Authentication',
    code: 'MSTG-AUTH-1',
    title: 'Biometric app lock',
    detail: 'Auto-lock after 1 min idle · PIN fallback.',
    dayLink: 'Day 183',
    route: AppRoutes.biometricLock,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_auth_2',
    category: 'Authentication',
    code: 'MSTG-AUTH-2',
    title: 'LP18 sensitive gates',
    detail: '6 operations require biometric/PIN before proceed.',
    dayLink: 'Day 184',
    route: AppRoutes.biometricHardening,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_resilience_1',
    category: 'Resilience',
    code: 'MSTG-RESILIENCE-1',
    title: 'Root / jailbreak detection',
    detail: '6 checks per platform · Safe Mode on compromise.',
    dayLink: 'Day 185',
    route: AppRoutes.rootDetection,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_resilience_2',
    category: 'Resilience',
    code: 'MSTG-RESILIENCE-2',
    title: 'Tamper + integrity alerts',
    detail: 'Play Integrity MEETS_DEVICE_INTEGRITY · tamper banner.',
    dayLink: 'Day 186',
    route: AppRoutes.tamperAlert,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_storage_1',
    category: 'Storage',
    code: 'MSTG-STORAGE-1',
    title: 'Encrypted local storage',
    detail: 'Hive AES-256 · JWT in Keychain/Keystore.',
    dayLink: 'Day 187',
    route: AppRoutes.secureStorage,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_crypto_1',
    category: 'Cryptography',
    code: 'MSTG-CRYPTO-1',
    title: 'Key rotation policy',
    detail: '90-day rotation · last rotation 2 days ago.',
    dayLink: 'Day 188',
    route: AppRoutes.keyRotation,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_platform_1',
    category: 'Platform',
    code: 'MSTG-PLATFORM-1',
    title: 'Security dashboard aggregate',
    detail: 'Full scan sim · 12 checks · score ring.',
    dayLink: 'Day 189',
    route: AppRoutes.securityDashboard,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_platform_2',
    category: 'Platform',
    code: 'MSTG-PLATFORM-2',
    title: 'Section C sign-off complete',
    detail: 'LP1-LP27 compliance badge · Section D handoff.',
    dayLink: 'Day 190',
    route: AppRoutes.sectionCComplete,
    defaultStatus: _AuditStatus.pass,
  ),
  _MasvsItem(
    id: 'mstg_code_1',
    category: 'Code',
    code: 'MSTG-CODE-1',
    title: 'Release obfuscation',
    detail: 'ProGuard/R8 + dart obfuscation on CI release lane.',
    dayLink: 'CI',
    route: AppRoutes.securityDashboard,
    defaultStatus: _AuditStatus.warn,
  ),
  _MasvsItem(
    id: 'mstg_privacy_1',
    category: 'Privacy',
    code: 'MSTG-PRIVACY-1',
    title: 'Data export + deletion APIs',
    detail: 'Section B contracts 166-180 — verify before launch.',
    dayLink: 'Days 166-180',
    route: AppRoutes.dataExportDownload,
    defaultStatus: _AuditStatus.warn,
  ),
];

_AuditStatus _statusFromString(String? s) {
  return switch (s) {
    'pass' => _AuditStatus.pass,
    'warn' => _AuditStatus.warn,
    'fail' => _AuditStatus.fail,
    _ => _AuditStatus.unchecked,
  };
}

String _statusToString(_AuditStatus s) => switch (s) {
      _AuditStatus.pass => 'pass',
      _AuditStatus.warn => 'warn',
      _AuditStatus.fail => 'fail',
      _AuditStatus.unchecked => 'unchecked',
    };

Color _statusColor(_AuditStatus s) => switch (s) {
      _AuditStatus.pass => ZapColors.safe,
      _AuditStatus.warn => ZapColors.warning,
      _AuditStatus.fail => ZapColors.danger,
      _AuditStatus.unchecked => ZapColors.textMuted,
    };

IconData _statusIcon(_AuditStatus s) => switch (s) {
      _AuditStatus.pass => Icons.check_circle_rounded,
      _AuditStatus.warn => Icons.warning_rounded,
      _AuditStatus.fail => Icons.cancel_rounded,
      _AuditStatus.unchecked => Icons.radio_button_unchecked_rounded,
    };

Map<String, dynamic> _auditPayload(Map<String, String> statuses) {
  final pass = statuses.values.where((v) => v == 'pass').length;
  final warn = statuses.values.where((v) => v == 'warn').length;
  final fail = statuses.values.where((v) => v == 'fail').length;
  return {
    'endpoint': 'GET /api/v1/security/prelaunch-audit/',
    'standard': 'OWASP MASVS L2',
    'total_items': _kMasvsItems.length,
    'pass': pass,
    'warn': warn,
    'fail': fail,
    'launch_ready': fail == 0 && warn <= 2,
    'items': _kMasvsItems
        .map(
          (i) => {
            'id': i.id,
            'code': i.code,
            'status': statuses[i.id] ?? _statusToString(i.defaultStatus),
            'day_link': i.dayLink,
          },
        )
        .toList(),
    'wire_note': 'Mock checklist · ties to Days 181-190 security block',
  };
}

String _buildAuditReport(Map<String, String> statuses) {
  final buf = StringBuffer('ZapSafe Pre-Launch Security Audit (MASVS L2)\n\n');
  String? lastCat;
  for (final item in _kMasvsItems) {
    if (item.category != lastCat) {
      buf.writeln('── ${item.category.toUpperCase()} ──');
      lastCat = item.category;
    }
    final st = _statusFromString(statuses[item.id]);
    final mark = switch (st) {
      _AuditStatus.pass => '[PASS]',
      _AuditStatus.warn => '[WARN]',
      _AuditStatus.fail => '[FAIL]',
      _AuditStatus.unchecked => '[    ]',
    };
    buf.writeln('$mark ${item.code} · ${item.title} (${item.dayLink})');
  }
  final payload = _auditPayload(statuses);
  buf.writeln();
  buf.writeln(
    'Summary: ${payload['pass']} pass · ${payload['warn']} warn · '
    '${payload['fail']} fail · launch_ready=${payload['launch_ready']}',
  );
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d285TabProvider = StateProvider<int>((ref) => 0);
final _d285StatusesProvider = StateProvider<Map<String, String>>((ref) {
  return {
    for (final i in _kMasvsItems) i.id: _statusToString(i.defaultStatus),
  };
});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day285SecurityPrelaunchAuditScreen extends ConsumerWidget {
  const Day285SecurityPrelaunchAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d285StatusesProvider);
    final pass = statuses.values.where((v) => v == 'pass').length;
    final total = _kMasvsItems.length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 285 · Security Audit'),
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
                  '$pass/$total PASS',
                  style: const TextStyle(
                    color: _kAccent,
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
          _TabBar(
            tab: ref.watch(_d285TabProvider),
            onSelect: (i) => ref.read(_d285TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d285TabProvider)) {
              0 => const _ChecklistTab(),
              1 => const _ProgressTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Checklist ────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  void _cycleStatus(WidgetRef ref, String id) {
    final current = _statusFromString(ref.read(_d285StatusesProvider)[id]);
    final next = switch (current) {
      _AuditStatus.pass => _AuditStatus.warn,
      _AuditStatus.warn => _AuditStatus.fail,
      _AuditStatus.fail => _AuditStatus.pass,
      _ => _AuditStatus.pass,
    };
    ref.read(_d285StatusesProvider.notifier).state = {
      ...ref.read(_d285StatusesProvider),
      id: _statusToString(next),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d285StatusesProvider);
    String? lastCat;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'OWASP MASVS L2 checklist',
          subtitle: 'Tap status chip to cycle pass → warn → fail · link to Day screen',
        ),
        ..._kMasvsItems.expand((item) {
          final widgets = <Widget>[];
          if (item.category != lastCat) {
            lastCat = item.category;
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(top: ZapSpacing.md, bottom: 4),
                child: Text(
                  item.category.toUpperCase(),
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            );
          }
          final st = _statusFromString(statuses[item.id]);
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusColor(st).withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _cycleStatus(ref, item.id),
                    child: Icon(_statusIcon(st), color: _statusColor(st), size: 22),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.code,
                          style: TextStyle(
                            color: _statusColor(st),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          item.detail,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ActionChip(
                          label: Text('${item.dayLink} →'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => context.push(item.route),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          return widgets;
        }),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d285StatusesProvider.notifier).state = {
              for (final i in _kMasvsItems) i.id: _statusToString(i.defaultStatus),
            };
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Checklist reset to defaults.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset checklist'),
        ),
      ],
    );
  }
}

// ── Tab 1: Progress ─────────────────────────────────────────────────────────
class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d285StatusesProvider);
    final payload = _auditPayload(statuses);
    final pass = payload['pass'] as int;
    final warn = payload['warn'] as int;
    final fail = payload['fail'] as int;
    final ready = payload['launch_ready'] as bool;
    final pct = pass / _kMasvsItems.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Pre-launch readiness',
          subtitle: 'MASVS L2 aggregate · launch_ready when fail=0 and warn≤2',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 10,
                      backgroundColor: ZapColors.border,
                      color: ready ? _kAccent : ZapColors.warning,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(pct * 100).round()}%',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          ready ? 'READY' : 'REVIEW',
                          style: TextStyle(
                            color: ready ? _kAccent : ZapColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),
              _StatRow(label: 'Pass', value: '$pass', color: ZapColors.safe),
              _StatRow(label: 'Warn', value: '$warn', color: ZapColors.warning),
              _StatRow(label: 'Fail', value: '$fail', color: ZapColors.danger),
            ],
          ),
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
            _buildAuditReport(statuses),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildAuditReport(statuses)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audit report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy audit report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ZapColors.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ─────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d285StatusesProvider);
    final payload = _auditPayload(statuses);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Security pre-launch audit',
          subtitle:
              'Maps OWASP MASVS L2 controls to Section C Days 181-190 work.',
        ),
        const _PolicyRow(
          icon: Icons.lock_rounded,
          title: 'Days 181-182 · Network',
          subtitle: 'Certificate pinning, NSC, ATS, proxy detection.',
        ),
        const _PolicyRow(
          icon: Icons.fingerprint_rounded,
          title: 'Days 183-184 · Auth',
          subtitle: 'Biometric lock, LP18 gates, hardware crypto binding.',
        ),
        const _PolicyRow(
          icon: Icons.shield_rounded,
          title: 'Days 185-190 · Resilience + sign-off',
          subtitle: 'Root/jailbreak, tamper, storage, rotation, dashboard.',
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
              const SnackBar(content: Text('Audit spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
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
            'Tomorrow: Day 286 — Legal Launch Blockers Tracker '
            '(export/deletion APIs · red/yellow/green).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 189 Dashboard'),
              onPressed: () => context.push(AppRoutes.securityDashboard),
            ),
            ActionChip(
              label: const Text('Day 190 Sign-off'),
              onPressed: () => context.push(AppRoutes.sectionCComplete),
            ),
            ActionChip(
              label: const Text('Day 284 Review Notes'),
              onPressed: () => context.push(AppRoutes.storeReviewNotes),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
