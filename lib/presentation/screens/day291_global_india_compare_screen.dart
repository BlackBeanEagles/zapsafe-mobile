/// Day 291 — Global vs India Release Compare
///
/// Section E (Days 281-300): side-by-side comparison table for global vs
/// India release — languages, SMS provider, emergency numbers, pricing.
///
/// Tag: 🟢 FRONTEND-ONLY · reference table · no live region API.
///
/// Route: [AppRoutes.globalIndiaCompare] → `/global-india-compare`
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
const _kAccent = Color(0xFFFF9933);
const _kIndiaGreen = Color(0xFF138808);
const _kTabs = ['Compare', 'Table', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _CompareCategory { languages, sms, emergency, pricing, compliance }

extension _CompareCategoryX on _CompareCategory {
  String get label => switch (this) {
        _CompareCategory.languages => 'Languages',
        _CompareCategory.sms => 'SMS provider',
        _CompareCategory.emergency => 'Emergency numbers',
        _CompareCategory.pricing => 'Pricing',
        _CompareCategory.compliance => 'Compliance',
      };

  IconData get icon => switch (this) {
        _CompareCategory.languages => Icons.language_rounded,
        _CompareCategory.sms => Icons.sms_rounded,
        _CompareCategory.emergency => Icons.emergency_rounded,
        _CompareCategory.pricing => Icons.payments_rounded,
        _CompareCategory.compliance => Icons.policy_rounded,
      };
}

class _CompareRow {
  const _CompareRow({
    required this.id,
    required this.category,
    required this.dimension,
    required this.globalValue,
    required this.indiaValue,
    required this.notes,
    this.differs = true,
  });

  final String id;
  final _CompareCategory category;
  final String dimension;
  final String globalValue;
  final String indiaValue;
  final String notes;
  final bool differs;
}

const _kCompareRows = [
  _CompareRow(
    id: 'lang_shipped',
    category: _CompareCategory.languages,
    dimension: 'Shipped at launch',
    globalValue: 'en + 14 locales (Day 261 hub)',
    indiaValue: 'en + hi + ta + te (Days 236–237)',
    notes: 'India soft launch prioritises Hindi and South Indian languages.',
  ),
  _CompareRow(
    id: 'lang_store',
    category: _CompareCategory.languages,
    dimension: 'Play Store listing',
    globalValue: 'en-US default · 8 store locales',
    indiaValue: 'hi-IN primary · en-IN secondary',
    notes: 'Day 239 store checklist · screenshots in Hindi.',
  ),
  _CompareRow(
    id: 'lang_rtl',
    category: _CompareCategory.languages,
    dimension: 'RTL packs',
    globalValue: 'fa (Day 263) · planned ar',
    indiaValue: 'Not in v1 India SKU',
    notes: 'Persian pack ships globally; India SKU defers RTL.',
    differs: false,
  ),
  _CompareRow(
    id: 'sms_provider',
    category: _CompareCategory.sms,
    dimension: 'OTP + SOS SMS',
    globalValue: 'Twilio / AWS SNS (global routes)',
    indiaValue: 'MSG91 (DLT-registered templates)',
    notes: 'Day 239 backend gate · TRAI DLT entity + template IDs.',
  ),
  _CompareRow(
    id: 'sms_fallback',
    category: _CompareCategory.sms,
    dimension: 'Offline fallback',
    globalValue: 'In-app push primary · SMS backup',
    indiaValue: 'Dual-SIM SMS + offline SOS UX (Day 245)',
    notes: 'India tests Jio/Airtel delivery latency heavily.',
  ),
  _CompareRow(
    id: 'sms_cost',
    category: _CompareCategory.sms,
    dimension: 'Per-message cost (mock)',
    globalValue: '\$0.0075 avg international',
    indiaValue: '₹0.18 domestic DLT',
    notes: 'Mock unit economics for launch P&L.',
  ),
  _CompareRow(
    id: 'emergency_primary',
    category: _CompareCategory.emergency,
    dimension: 'Primary emergency',
    globalValue: '112 / 911 (region auto, Day 238)',
    indiaValue: '112 (ERSS) + 100 police',
    notes: 'Day 238 region table · India ERSS unified dial.',
  ),
  _CompareRow(
    id: 'emergency_women',
    category: _CompareCategory.emergency,
    dimension: 'Women helpline',
    globalValue: 'Varies by country preset',
    indiaValue: '181 · 1091 (state variants)',
    notes: 'Shown in India onboarding Step 4.',
  ),
  _CompareRow(
    id: 'emergency_counselor',
    category: _CompareCategory.emergency,
    dimension: 'In-app counselor',
    globalValue: '24/7 English queue',
    indiaValue: 'Hindi + English counselors (Day 278)',
    notes: 'India queue shows bilingual ETA strip.',
  ),
  _CompareRow(
    id: 'price_monthly',
    category: _CompareCategory.pricing,
    dimension: 'Premium monthly',
    globalValue: '\$4.99 USD',
    indiaValue: '₹199 / month',
    notes: 'Play billing price tier · PPP adjusted.',
  ),
  _CompareRow(
    id: 'price_annual',
    category: _CompareCategory.pricing,
    dimension: 'Premium annual',
    globalValue: '\$39.99 USD',
    indiaValue: '₹1,499 / year',
    notes: '~37% savings vs monthly · UPI-friendly.',
  ),
  _CompareRow(
    id: 'price_free',
    category: _CompareCategory.pricing,
    dimension: 'Free tier SOS',
    globalValue: 'Full SOS + 3 contacts',
    indiaValue: 'Same · India insurance mock (Day 272)',
    notes: 'Parity on core safety; India adds partner offers.',
    differs: false,
  ),
  _CompareRow(
    id: 'compliance_data',
    category: _CompareCategory.compliance,
    dimension: 'Data residency',
    globalValue: 'AWS us-east-1 + eu-west-1',
    indiaValue: 'ap-south-1 (Mumbai) target',
    notes: 'Section B GDPR export still global contract.',
  ),
  _CompareRow(
    id: 'compliance_dlt',
    category: _CompareCategory.compliance,
    dimension: 'SMS compliance',
    globalValue: 'TCPA / opt-in where required',
    indiaValue: 'TRAI DLT + PE-TM registration',
    notes: 'Blocking gate for India OTP until MSG91 live.',
  ),
];

Map<String, dynamic> _comparePayload({
  required _CompareCategory? filter,
  required int highlightedDiffs,
}) =>
    {
      'endpoint': 'GET /api/v1/release/region-compare/',
      'regions': ['global', 'india'],
      'row_count': _kCompareRows.length,
      'diff_count': highlightedDiffs,
      'filter': filter?.name,
      'dimensions': [
        'languages',
        'sms_provider',
        'emergency_numbers',
        'pricing',
      ],
      'wire_note': 'Mock compare table · ties to Day 239 India readiness',
    };

String _buildCompareCsv() {
  final buf = StringBuffer('dimension,global,india,notes\n');
  for (final r in _kCompareRows) {
    buf.writeln(
      '${r.dimension},${r.globalValue.replaceAll(',', ';')},'
      '${r.indiaValue.replaceAll(',', ';')},${r.notes.replaceAll(',', ';')}',
    );
  }
  return buf.toString();
}

String _buildCompareReport({required _CompareCategory? filter}) {
  final rows = filter == null
      ? _kCompareRows
      : _kCompareRows.where((r) => r.category == filter);
  final buf = StringBuffer('ZapSafe Global vs India Release Compare\n\n');
  _CompareCategory? lastCat;
  for (final r in rows) {
    if (r.category != lastCat) {
      buf.writeln('── ${r.category.label.toUpperCase()} ──');
      lastCat = r.category;
    }
    buf.writeln(r.dimension);
    buf.writeln('  Global: ${r.globalValue}');
    buf.writeln('  India:  ${r.indiaValue}');
    buf.writeln('  Note: ${r.notes}');
    buf.writeln();
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d291TabProvider = StateProvider<int>((ref) => 0);
final _d291CategoryFilterProvider =
    StateProvider<_CompareCategory?>((ref) => null);
final _d291ShowDiffsOnlyProvider = StateProvider<bool>((ref) => false);

List<_CompareRow> _filteredRows(WidgetRef ref) {
  final cat = ref.watch(_d291CategoryFilterProvider);
  final diffsOnly = ref.watch(_d291ShowDiffsOnlyProvider);
  return _kCompareRows.where((r) {
    if (cat != null && r.category != cat) return false;
    if (diffsOnly && !r.differs) return false;
    return true;
  }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day291GlobalIndiaCompareScreen extends ConsumerWidget {
  const Day291GlobalIndiaCompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diffCount = _kCompareRows.where((r) => r.differs).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 291 · Global vs India'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$diffCount diffs',
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
            tab: ref.watch(_d291TabProvider),
            onSelect: (i) => ref.read(_d291TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d291TabProvider)) {
              0 => const _CompareTab(),
              1 => const _TableTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Compare (card view) ────────────────────────────────────────────────
class _CompareTab extends ConsumerWidget {
  const _CompareTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = _filteredRows(ref);
    final cat = ref.watch(_d291CategoryFilterProvider);
    final diffsOnly = ref.watch(_d291ShowDiffsOnlyProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Release region compare',
          subtitle: 'Global default SKU vs India soft-launch SKU',
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: ZapColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌍 GLOBAL',
                      style: TextStyle(
                        color: ZapColors.info,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                    SizedBox(height: ZapSpacing.xs),
                    Text(
                      '14+ locales · Twilio · USD pricing',
                      style: TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: _kIndiaGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: _kIndiaGreen.withOpacity(0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🇮🇳 INDIA',
                      style: TextStyle(
                        color: _kIndiaGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                    SizedBox(height: ZapSpacing.xs),
                    Text(
                      'hi/ta/te · MSG91 · ₹ pricing · ERSS 112',
                      style: TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: cat == null,
              onSelected: (_) =>
                  ref.read(_d291CategoryFilterProvider.notifier).state = null,
            ),
            ..._CompareCategory.values.map(
              (c) => FilterChip(
                label: Text(c.label),
                selected: cat == c,
                onSelected: (_) =>
                    ref.read(_d291CategoryFilterProvider.notifier).state = c,
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Show differences only',
            style: TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          ),
          value: diffsOnly,
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d291ShowDiffsOnlyProvider.notifier).state = v,
        ),
        ...rows.map((r) => _CompareCard(row: r)),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.row});

  final _CompareRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: row.differs ? _kAccent.withOpacity(0.35) : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(row.category.icon, size: 16, color: _kAccent),
              const SizedBox(width: 6),
              Text(
                row.category.label,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (row.differs) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DIFF',
                    style: TextStyle(
                      color: _kAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.dimension,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          _ValueRow(
              label: 'Global', value: row.globalValue, color: ZapColors.info),
          const SizedBox(height: ZapSpacing.xs),
          _ValueRow(label: 'India', value: row.indiaValue, color: _kIndiaGreen),
          const SizedBox(height: 6),
          Text(
            row.notes,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Table ──────────────────────────────────────────────────────────────
class _TableTab extends ConsumerWidget {
  const _TableTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = _filteredRows(ref);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Comparison table',
          subtitle: 'Export-ready · 14 dimensions',
        ),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: ZapColors.border)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Dimension',
                        style: TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Global',
                        style: TextStyle(
                          color: ZapColors.info,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'India',
                        style: TextStyle(
                          color: _kIndiaGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...rows.map(
                (r) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: ZapColors.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          r.dimension,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.globalValue,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.indiaValue,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildCompareCsv()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comparison CSV copied.')),
            );
          },
          icon: const Icon(Icons.table_chart_rounded, size: 18),
          label: const Text('Copy CSV'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildCompareReport(
                  filter: ref.read(_d291CategoryFilterProvider),
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comparison report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy text report'),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diffCount = _kCompareRows.where((r) => r.differs).length;
    final payload = _comparePayload(
      filter: ref.watch(_d291CategoryFilterProvider),
      highlightedDiffs: diffCount,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Global vs India release',
          subtitle: 'Side-by-side SKU differences before multi-region launch.',
        ),
        const _PolicyRow(
          icon: Icons.language_rounded,
          title: 'Languages',
          subtitle: 'Global hub (Day 261) vs hi/ta/te India packs.',
        ),
        const _PolicyRow(
          icon: Icons.sms_rounded,
          title: 'SMS provider',
          subtitle: 'Twilio global vs MSG91 + DLT for India (Day 239).',
        ),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'Emergency numbers',
          subtitle: 'ERSS 112 + state helplines vs global presets (Day 238).',
        ),
        const _PolicyRow(
          icon: Icons.payments_rounded,
          title: 'Pricing',
          subtitle: 'USD tiers vs ₹ PPP-adjusted Play billing.',
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
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
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
              const SnackBar(content: Text('Compare spec copied.')),
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
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 292 — Post-Launch Monitoring Plan '
            '(72h war room · crash · SOS · support).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 239 India Readiness'),
              onPressed: () => context.push(AppRoutes.indiaLaunchReadiness),
            ),
            ActionChip(
              label: const Text('Day 238 Emergency #'),
              onPressed: () => context.push(AppRoutes.regionEmergencyNumbers),
            ),
            ActionChip(
              label: const Text('Day 290 Staged Rollout'),
              onPressed: () => context.push(AppRoutes.stagedRolloutSimulator),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
