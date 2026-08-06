/// Day 239 — India Soft Launch Readiness
///
/// Section B (Days 221-240): checklist for India soft launch — Hindi/Tamil/Telugu
/// QA, MSG91 backend, offline SOS, store listing hi-IN region, emergency numbers.
///
/// Tag: 🟢 FRONTEND-ONLY · launch gate before Section B milestone (Day 240).
///
/// Route: [AppRoutes.indiaLaunchReadiness] → `/india-launch-readiness`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Checklist model ───────────────────────────────────────────────────────────
enum _ReadinessCategory { i18n, backend, sos, store, compliance }

enum _ItemTag { frontend, backend, mock }

extension _ReadinessCategoryX on _ReadinessCategory {
  String get label => switch (this) {
        _ReadinessCategory.i18n => 'i18n / UX',
        _ReadinessCategory.backend => 'Backend',
        _ReadinessCategory.sos => 'SOS & Safety',
        _ReadinessCategory.store => 'Store Listing',
        _ReadinessCategory.compliance => 'Compliance',
      };

  Color get color => switch (this) {
        _ReadinessCategory.i18n => const Color(0xFFF59E0B),
        _ReadinessCategory.backend => ZapColors.info,
        _ReadinessCategory.sos => ZapColors.danger,
        _ReadinessCategory.store => const Color(0xFF10B981),
        _ReadinessCategory.compliance => const Color(0xFF8B5CF6),
      };
}

extension _ItemTagX on _ItemTag {
  String get label => switch (this) {
        _ItemTag.frontend => '🟢 FRONTEND',
        _ItemTag.backend => '🔵 BACKEND',
        _ItemTag.mock => '🟡 MOCK-NOW',
      };
}

class _IndiaReadinessItem {
  const _IndiaReadinessItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.tag,
    this.route,
    this.critical = false,
  });

  final String id;
  final _ReadinessCategory category;
  final String title;
  final String description;
  final _ItemTag tag;
  final String? route;
  final bool critical;
}

const _kChecklist = [
  _IndiaReadinessItem(
    id: 'hi_qa',
    category: _ReadinessCategory.i18n,
    title: 'Hindi copy QA complete',
    description:
        'Day 236 — 20 critical hi_IN strings reviewed; truncation flags addressed.',
    tag: _ItemTag.frontend,
    route: AppRoutes.hindiUxQa,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'ta_qa',
    category: _ReadinessCategory.i18n,
    title: 'Tamil layout QA complete',
    description:
        'Day 237 — Tamil long-script line breaks audited in button/card previews.',
    tag: _ItemTag.frontend,
    route: AppRoutes.tamilTeluguQa,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'te_qa',
    category: _ReadinessCategory.i18n,
    title: 'Telugu layout QA complete',
    description:
        'Day 237 — Telugu layout flags cleared or documented with fix pattern.',
    tag: _ItemTag.frontend,
    route: AppRoutes.tamilTeluguQa,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'i18n_coverage',
    category: _ReadinessCategory.i18n,
    title: 'en_IN + hi_IN locale coverage reviewed',
    description:
        'Day 216 i18n audit — Hindi ≥90% critical paths; Tamil/Telugu Phase 2 tracked.',
    tag: _ItemTag.frontend,
    route: AppRoutes.i18nCoverageAudit,
  ),
  _IndiaReadinessItem(
    id: 'msg91',
    category: _ReadinessCategory.backend,
    title: 'MSG91 SMS gateway ready',
    description:
        'OTP + SOS contact verify via MSG91 API · DLT template IDs registered · '
        '+91 sender ID approved.',
    tag: _ItemTag.mock,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'msg91_fallback',
    category: _ReadinessCategory.backend,
    title: 'SMS fallback if MSG91 down',
    description:
        'Queue OTP retries · show offline verify path · alert ops if delivery fails.',
    tag: _ItemTag.backend,
  ),
  _IndiaReadinessItem(
    id: 'offline_sos',
    category: _ReadinessCategory.sos,
    title: 'Offline SOS queue tested',
    description:
        'SOS fires with no network · queued payload syncs when online · '
        'Day 51 offline status + Day 207 chat queue.',
    tag: _ItemTag.frontend,
    route: AppRoutes.offlineStatus,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'offline_sos_device',
    category: _ReadinessCategory.sos,
    title: 'Device harness offline SOS pass',
    description:
        'Day 201 device harness — airplane mode SOS → local alert + queue badge.',
    tag: _ItemTag.frontend,
    route: AppRoutes.deviceQaHarness,
  ),
  _IndiaReadinessItem(
    id: 'emergency_112',
    category: _ReadinessCategory.sos,
    title: 'ERSS 112 + regional numbers bundled',
    description:
        'Day 238 — India 112/100/101/102 in assets/data/emergency_numbers.json · tel: dialer.',
    tag: _ItemTag.frontend,
    route: AppRoutes.regionEmergencyNumbers,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'escalation_112',
    category: _ReadinessCategory.sos,
    title: 'Escalation policy includes 112 auto-call',
    description:
        'Tier-2 escalation can dial ERSS when enabled · user consent on file.',
    tag: _ItemTag.frontend,
    route: AppRoutes.escalationPoliciesV2,
  ),
  _IndiaReadinessItem(
    id: 'hi_listing',
    category: _ReadinessCategory.store,
    title: 'Play Console hi-IN listing uploaded',
    description:
        'Day 194 — Hindi title, short description, full description in Devanagari.',
    tag: _ItemTag.frontend,
    route: AppRoutes.storeListingExtra,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'hi_screenshots',
    category: _ReadinessCategory.store,
    title: 'Hindi screenshots (hi_IN slot)',
    description:
        'Day 192 — 6 screens with Hindi overlay text uploaded to Play/App Store.',
    tag: _ItemTag.frontend,
    route: AppRoutes.screenshotFrames,
  ),
  _IndiaReadinessItem(
    id: 'india_region',
    category: _ReadinessCategory.store,
    title: 'Store rollout: India region selected',
    description:
        'Play staged rollout → India · App Store availability → India · '
        'pricing INR tier set.',
    tag: _ItemTag.mock,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'aso_in',
    category: _ReadinessCategory.store,
    title: 'India ASO keywords validated',
    description:
        'Day 193 store listing — hi_IN keywords, competitor scan, 170-char promo text.',
    tag: _ItemTag.frontend,
    route: AppRoutes.storeListing,
  ),
  _IndiaReadinessItem(
    id: 'dpdp_consent',
    category: _ReadinessCategory.compliance,
    title: 'DPDP consent copy reviewed',
    description:
        'Day 161 consent gate · Hindi legal strings · data processing purpose clear.',
    tag: _ItemTag.frontend,
    route: AppRoutes.consentGate,
    critical: true,
  ),
  _IndiaReadinessItem(
    id: 'data_safety_in',
    category: _ReadinessCategory.compliance,
    title: 'Play Data Safety — India declarations',
    description:
        'Day 164 data safety labels match India collection practices · SOS location disclosed.',
    tag: _ItemTag.frontend,
    route: AppRoutes.dataSafety,
  ),
  _IndiaReadinessItem(
    id: 'referral_in',
    category: _ReadinessCategory.compliance,
    title: 'Referral rewards India terms',
    description:
        'Day 225 referral — INR rewards copy · no lottery/regulated promo violations.',
    tag: _ItemTag.frontend,
    route: AppRoutes.referralRewards,
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d239TabProvider = StateProvider<int>((ref) => 0);
final _d239CheckedProvider = StateProvider<Set<String>>((ref) => {});
final _d239CategoryProvider =
    StateProvider<_ReadinessCategory?>((ref) => null);
final _d239Msg91MockProvider = StateProvider<bool>((ref) => false);

const _kTabs = ['Checklist', 'Gates', 'Sign-off'];

int _criticalDone(Set<String> checked) =>
    _kChecklist.where((i) => i.critical && checked.contains(i.id)).length;

int get _criticalTotal => _kChecklist.where((i) => i.critical).length;

String _buildReport(Set<String> checked, bool msg91Mock) {
  final buf = StringBuffer('ZapSafe India Soft Launch Readiness\n');
  buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
  buf.writeln(
    'Progress: ${checked.length}/${_kChecklist.length} · '
    'Critical: ${_criticalDone(checked)}/$_criticalTotal',
  );
  buf.writeln('MSG91 mock status: ${msg91Mock ? "READY (mock)" : "PENDING"}');
  buf.writeln('');
  for (final item in _kChecklist) {
    final done = checked.contains(item.id);
    buf.writeln(
      '[${item.category.label}] ${item.id} · ${done ? "DONE" : "OPEN"}'
      '${item.critical ? " · CRITICAL" : ""}',
    );
    buf.writeln('  ${item.title}');
    buf.writeln('  ${item.description}');
    buf.writeln('');
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day239IndiaLaunchReadinessScreen extends ConsumerWidget {
  const Day239IndiaLaunchReadinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d239TabProvider);
    final checked = ref.watch(_d239CheckedProvider);
    final criticalDone = _criticalDone(checked);
    final allCritical = criticalDone == _criticalTotal;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 239 · India Launch'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: allCritical
                      ? ZapColors.safe.withOpacity(0.15)
                      : ZapColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: allCritical
                        ? ZapColors.safe.withOpacity(0.45)
                        : ZapColors.warning.withOpacity(0.45),
                  ),
                ),
                child: Text(
                  allCritical ? 'CRITICAL ✅' : '$criticalDone/$_criticalTotal CRIT',
                  style: TextStyle(
                    color: allCritical ? ZapColors.safe : ZapColors.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
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
            onSelect: (i) => ref.read(_d239TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _ChecklistTab(),
              1 => const _GatesTab(),
              _ => const _SignOffTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d239CheckedProvider);
    final category = ref.watch(_d239CategoryProvider);
    final items = category == null
        ? _kChecklist
        : _kChecklist.where((i) => i.category == category).toList();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section B Day 19/20 · India soft launch gate · '
            '17 checklist items · 8 critical',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        _ProgressCard(checked: checked),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('All', style: TextStyle(fontSize: 10)),
              selected: category == null,
              onSelected: (_) =>
                  ref.read(_d239CategoryProvider.notifier).state = null,
            ),
            ..._ReadinessCategory.values.map(
              (c) => FilterChip(
                label: Text(c.label, style: const TextStyle(fontSize: 10)),
                selected: category == c,
                onSelected: (_) =>
                    ref.read(_d239CategoryProvider.notifier).state = c,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...items.map(
          (item) => _ChecklistRow(
            item: item,
            checked: checked.contains(item.id),
            onToggle: (v) {
              ref.read(_d239CheckedProvider.notifier).update((set) {
                final next = Set<String>.from(set);
                if (v) {
                  next.add(item.id);
                } else {
                  next.remove(item.id);
                }
                return next;
              });
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(_d239CheckedProvider.notifier).state = {},
                child: const Text('Clear all'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  ref.read(_d239CheckedProvider.notifier).state = {
                    for (final i in _kChecklist) i.id,
                  };
                  ref.read(_d239Msg91MockProvider.notifier).state = true;
                },
                style: FilledButton.styleFrom(backgroundColor: ZapColors.safe),
                child: const Text('Mark all done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final Set<String> checked;

  const _ProgressCard({required this.checked});

  @override
  Widget build(BuildContext context) {
    final total = _kChecklist.length;
    final progress = checked.length / total;
    final critDone = _criticalDone(checked);
    final critTotal = _criticalTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: ZapColors.border,
                  color: progress == 1 ? ZapColors.safe : ZapColors.info,
                ),
                Text(
                  '${checked.length}',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${checked.length}/$total items complete',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Critical: $critDone/$critTotal · '
                  '${critDone == critTotal ? "Ready for sign-off ✅" : "Complete critical items first"}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: critDone / critTotal,
                    minHeight: 6,
                    backgroundColor: ZapColors.border,
                    color: critDone == critTotal
                        ? ZapColors.safe
                        : ZapColors.warning,
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

class _ChecklistRow extends StatelessWidget {
  final _IndiaReadinessItem item;
  final bool checked;
  final ValueChanged<bool> onToggle;

  const _ChecklistRow({
    required this.item,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked
              ? ZapColors.safe.withOpacity(0.45)
              : item.critical
                  ? ZapColors.warning.withOpacity(0.35)
                  : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            dense: true,
            value: checked,
            onChanged: (v) => onToggle(v ?? false),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (item.critical)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ZapColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CRITICAL',
                      style: TextStyle(
                        color: ZapColors.danger,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.tag.label,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            secondary: Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: item.category.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (item.route != null)
            Padding(
              padding: const EdgeInsets.only(
                left: ZapSpacing.lg,
                right: ZapSpacing.md,
                bottom: ZapSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push(item.route!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'Open screen',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tab 1: Gates ──────────────────────────────────────────────────────────────
class _GatesTab extends ConsumerWidget {
  const _GatesTab();

  bool _categoryDone(Set<String> checked, _ReadinessCategory cat) {
    final items = _kChecklist.where((i) => i.category == cat);
    return items.every((i) => checked.contains(i.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d239CheckedProvider);
    final msg91Mock = ref.watch(_d239Msg91MockProvider);

    final gates = [
      _GateCard(
        title: 'i18n gate',
        subtitle: 'Hindi + Tamil + Telugu QA + locale audit',
        passed: _categoryDone(checked, _ReadinessCategory.i18n),
        detail: 'Days 236-237 · Day 216 coverage',
        color: const Color(0xFFF59E0B),
      ),
      _GateCard(
        title: 'Backend gate',
        subtitle: 'MSG91 SMS + OTP delivery',
        passed: msg91Mock && checked.contains('msg91'),
        detail: msg91Mock
            ? 'Mock: MSG91 templates approved · sender ID ZAPSAFE'
            : 'Toggle mock ready below when backend confirms',
        color: ZapColors.info,
        extra: SwitchListTile(
          dense: true,
          title: const Text(
            'MSG91 mock ready',
            style: TextStyle(color: ZapColors.textPrimary, fontSize: 12),
          ),
          subtitle: const Text(
            'Simulates backend green · unblocks sign-off demo',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
          value: msg91Mock,
          onChanged: (v) =>
              ref.read(_d239Msg91MockProvider.notifier).state = v,
        ),
      ),
      _GateCard(
        title: 'SOS gate',
        subtitle: 'Offline queue + ERSS 112 numbers',
        passed: _categoryDone(checked, _ReadinessCategory.sos),
        detail: 'Days 51 · 201 · 207 · 238',
        color: ZapColors.danger,
      ),
      _GateCard(
        title: 'Store gate',
        subtitle: 'hi-IN listing + India rollout region',
        passed: _categoryDone(checked, _ReadinessCategory.store),
        detail: 'Days 192-194 · Play Console hi-IN slot',
        color: const Color(0xFF10B981),
      ),
    ];

    final passedCount = gates.where((g) => g.passed).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Text(
            passedCount == gates.length
                ? 'All 4 launch gates pass ✅'
                : '$passedCount/${gates.length} gates pass · complete checklist + MSG91 mock',
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...gates,
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 236 Hindi'),
              onPressed: () => context.push(AppRoutes.hindiUxQa),
            ),
            ActionChip(
              label: const Text('Day 237 TA/TE'),
              onPressed: () => context.push(AppRoutes.tamilTeluguQa),
            ),
            ActionChip(
              label: const Text('Day 240 Section B ✅'),
              onPressed: () => context.push(AppRoutes.sectionBCatchupMilestone),
            ),
          ],
        ),
      ],
    );
  }
}

class _GateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final bool passed;
  final Color color;
  final Widget? extra;

  const _GateCard({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.passed,
    required this.color,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed ? ZapColors.safe.withOpacity(0.45) : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: passed ? ZapColors.safe : color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                passed ? 'PASS' : 'OPEN',
                style: TextStyle(
                  color: passed ? ZapColors.safe : ZapColors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          if (extra != null) ...[
            const Divider(height: 16, color: ZapColors.border),
            extra!,
          ],
        ],
      ),
    );
  }
}

// ── Tab 2: Sign-off ───────────────────────────────────────────────────────────
class _SignOffTab extends ConsumerWidget {
  const _SignOffTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d239CheckedProvider);
    final msg91Mock = ref.watch(_d239Msg91MockProvider);
    final critDone = _criticalDone(checked);
    final critTotal = _criticalTotal;
    final allCritical = critDone == critTotal;
    final allDone = checked.length == _kChecklist.length;
    final launchReady = allCritical && msg91Mock && allDone;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (launchReady ? ZapColors.safe : ZapColors.warning)
                    .withOpacity(0.18),
                ZapColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (launchReady ? ZapColors.safe : ZapColors.warning)
                  .withOpacity(0.35),
            ),
          ),
          child: Column(
            children: [
              Icon(
                launchReady ? Icons.rocket_launch_rounded : Icons.hourglass_top_rounded,
                color: launchReady ? ZapColors.safe : ZapColors.warning,
                size: 40,
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                launchReady
                    ? 'India soft launch READY'
                    : 'India soft launch IN PROGRESS',
                style: TextStyle(
                  color: launchReady ? ZapColors.safe : ZapColors.warning,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                launchReady
                    ? 'All critical items, full checklist, and MSG91 mock gate pass.'
                    : 'Complete $critTotal critical items · '
                        '${_kChecklist.length} total · enable MSG91 mock on Gates tab.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _SignOffRow(
          label: 'Checklist',
          value: '${checked.length}/${_kChecklist.length}',
          ok: allDone,
        ),
        _SignOffRow(
          label: 'Critical items',
          value: '$critDone/$critTotal',
          ok: allCritical,
        ),
        _SignOffRow(
          label: 'MSG91 backend',
          value: msg91Mock ? 'Mock ready' : 'Pending',
          ok: msg91Mock,
        ),
        const _SignOffRow(
          label: 'Section B progress',
          value: 'Day 19/20',
          ok: false,
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
          child: const Text(
            'India launch scope:\n'
            '• hi_IN / ta_IN / te_IN UX QA (Days 236-237)\n'
            '• MSG91 OTP + SOS SMS (backend)\n'
            '• Offline SOS + ERSS 112 (Days 51, 201, 238)\n'
            '• Play hi-IN listing + India rollout (Days 192-194)\n'
            '• DPDP consent + data safety (Days 161, 164)',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _buildReport(checked, msg91Mock)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied India launch report')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy launch report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: ZapColors.info,
          ),
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
            'Tomorrow: Day 241 — Journey Mode v2 (Section C begins).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SignOffRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _SignOffRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: ok ? ZapColors.safe : ZapColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: ok ? ZapColors.safe : ZapColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
                        color: selected ? ZapColors.info : Colors.transparent,
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
                      fontSize: 10,
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
