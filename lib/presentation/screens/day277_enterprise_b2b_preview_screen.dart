/// Day 277 — Enterprise B2B Preview
///
/// Section D (Days 261-280): employer dashboard mock for night-shift bulk
/// license management — seat allocation, roster status, quote flow.
///
/// Tag: 🟡 MOCK-NOW · GET /api/v1/enterprise/tenants/ (mock).
///
/// Route: [AppRoutes.enterpriseB2bPreview] → `/enterprise-b2b-preview`
library;

import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF1E3A5F);
const _kTabs = ['Dashboard', 'Licenses', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kCompanyName = 'Nova Logistics Pvt Ltd';
const _kIndustry = 'Night-shift warehouse & last-mile fleet';

class _LicenseTier {
  const _LicenseTier({
    required this.id,
    required this.name,
    required this.seats,
    required this.pricePerSeat,
    required this.summary,
  });

  final String id;
  final String name;
  final int seats;
  final int pricePerSeat;
  final String summary;
}

const _kTiers = [
  _LicenseTier(
    id: 'starter',
    name: 'Starter',
    seats: 50,
    pricePerSeat: 149,
    summary: 'Single site · basic SOS + journey mode',
  ),
  _LicenseTier(
    id: 'growth',
    name: 'Growth',
    seats: 250,
    pricePerSeat: 119,
    summary: 'Multi-site · admin dashboard · heatmap opt-in',
  ),
  _LicenseTier(
    id: 'enterprise',
    name: 'Enterprise',
    seats: 1000,
    pricePerSeat: 89,
    summary: 'Bulk SSO · SLA · custom night-shift policies',
  ),
];

class _ShiftWorker {
  const _ShiftWorker({
    required this.id,
    required this.name,
    required this.role,
    required this.shift,
    required this.status,
    required this.score,
  });

  final String id;
  final String name;
  final String role;
  final String shift;
  final String status;
  final int score;
}

const _kNightShiftRoster = [
  _ShiftWorker(
    id: 'w01',
    name: 'Ananya R.',
    role: 'Picker',
    shift: '22:00 – 06:00',
    status: 'on_journey',
    score: 84,
  ),
  _ShiftWorker(
    id: 'w02',
    name: 'Priya S.',
    role: 'Dispatcher',
    shift: '22:00 – 06:00',
    status: 'checked_in',
    score: 91,
  ),
  _ShiftWorker(
    id: 'w03',
    name: 'Meera K.',
    role: 'Driver',
    shift: '23:00 – 07:00',
    status: 'on_journey',
    score: 78,
  ),
  _ShiftWorker(
    id: 'w04',
    name: 'Sneha V.',
    role: 'Supervisor',
    shift: '21:00 – 05:00',
    status: 'checked_in',
    score: 88,
  ),
  _ShiftWorker(
    id: 'w05',
    name: 'Kavya N.',
    role: 'Picker',
    shift: '22:00 – 06:00',
    status: 'offline',
    score: 72,
  ),
];

const _kWeeklyUtilization = [62.0, 68.0, 71.0, 74.0, 79.0, 81.0, 80.0];
const _kUtilLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _formatInr(int amount) => '₹${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';

Map<String, dynamic> _enterprisePayload({
  required int tierIndex,
  required int allocatedSeats,
  required bool quoteSent,
}) {
  final tier = _kTiers[tierIndex];
  return {
    'endpoint': 'GET /api/v1/enterprise/tenants/{tenant_id}/',
    'company': _kCompanyName,
    'industry': _kIndustry,
    'license_tier': tier.id,
    'allocated_seats': allocatedSeats,
    'active_seats': 198,
    'on_journey_now': 12,
    'sos_today': 0,
    'monthly_total_inr': allocatedSeats * tier.pricePerSeat,
    'quote_sent': quoteSent,
    'night_shift_roster_count': _kNightShiftRoster.length,
    'wire_note': 'Mock B2B preview · wire to enterprise tenant API later',
  };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d277TabProvider = StateProvider<int>((ref) => 0);
final _d277TierIndexProvider = StateProvider<int>((ref) => 1);
final _d277SeatsProvider = StateProvider<int>((ref) => 250);
final _d277QuoteSentProvider = StateProvider<bool>((ref) => false);
final _d277RequestingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day277EnterpriseB2bPreviewScreen extends ConsumerWidget {
  const Day277EnterpriseB2bPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteSent = ref.watch(_d277QuoteSentProvider);
    final requesting = ref.watch(_d277RequestingProvider);
    final seats = ref.watch(_d277SeatsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 277 · Enterprise B2B Preview'),
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
                  requesting
                      ? 'SENDING…'
                      : quoteSent
                          ? 'QUOTE SENT ✅'
                          : '$seats SEATS',
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
            tab: ref.watch(_d277TabProvider),
            onSelect: (i) => ref.read(_d277TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d277TabProvider)) {
              0 => const _DashboardTab(),
              1 => const _LicensesTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Dashboard ──────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  Color _statusColor(String status) => switch (status) {
        'on_journey' => ZapColors.info,
        'checked_in' => ZapColors.safe,
        _ => ZapColors.textMuted,
      };

  String _statusLabel(String status) => switch (status) {
        'on_journey' => 'On journey',
        'checked_in' => 'Checked in',
        _ => 'Offline',
      };

  @override
  Widget build(BuildContext context) {
    final onJourney =
        _kNightShiftRoster.where((w) => w.status == 'on_journey').length;

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
            '🟡 MOCK-NOW · Section D Day 17/20 · employer dashboard · night-shift roster · bulk licenses',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kAccent.withOpacity(0.25),
                _kAccent.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _kCompanyName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: ZapSpacing.xs),
                        Text(
                          _kIndustry,
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.lg),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _KpiChip(label: 'Licensed seats', value: '248'),
                  _KpiChip(label: 'Active users', value: '198'),
                  _KpiChip(label: 'On journey now', value: '12'),
                  _KpiChip(label: 'SOS today', value: '0'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Seat utilization (7 days)',
          subtitle: 'Night-shift activation rate · mock',
        ),
        const _UtilizationChart(values: _kWeeklyUtilization),
        const SizedBox(height: ZapSpacing.lg),
        _SectionTitle(
          title: 'Night-shift roster',
          subtitle: '$onJourney workers on journey · live mock status',
        ),
        ..._kNightShiftRoster.map(
          (worker) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _statusColor(worker.status).withOpacity(0.15),
                  child: Text(
                    worker.name.substring(0, 1),
                    style: TextStyle(
                      color: _statusColor(worker.status),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${worker.role} · ${worker.shift}',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _statusLabel(worker.status),
                      style: TextStyle(
                        color: _statusColor(worker.status),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Score ${worker.score}',
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Licenses ───────────────────────────────────────────────────────────
class _LicensesTab extends ConsumerWidget {
  const _LicensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierIndex = ref.watch(_d277TierIndexProvider);
    final seats = ref.watch(_d277SeatsProvider);
    final quoteSent = ref.watch(_d277QuoteSentProvider);
    final requesting = ref.watch(_d277RequestingProvider);
    final tier = _kTiers[tierIndex];
    final monthlyTotal = seats * tier.pricePerSeat;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Bulk license tier',
          subtitle: 'Night-shift workforce packages · mock pricing',
        ),
        ...List.generate(_kTiers.length, (i) {
          final t = _kTiers[i];
          final selected = tierIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.read(_d277TierIndexProvider.notifier).state = i;
                  ref.read(_d277SeatsProvider.notifier).state = t.seats;
                  ref.read(_d277QuoteSentProvider.notifier).state = false;
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(
                    color: selected
                        ? _kAccent.withOpacity(0.12)
                        : ZapColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? _kAccent : ZapColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: TextStyle(
                                color: selected
                                    ? _kAccent
                                    : ZapColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              t.summary,
                              style: const TextStyle(
                                color: ZapColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${t.seats} seats',
                            style: const TextStyle(
                              color: ZapColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_formatInr(t.pricePerSeat)}/seat/mo',
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Seat allocation',
          subtitle: 'Adjust seats for quote · capped by tier maximum',
        ),
        Row(
          children: [
            Text(
              '$seats seats',
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Text(
              '${_formatInr(monthlyTotal)}/mo',
              style: const TextStyle(
                color: _kAccent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Slider(
          value: seats.toDouble(),
          min: 25,
          max: tier.seats.toDouble(),
          divisions: ((tier.seats - 25) / 25).round().clamp(1, 20),
          activeColor: _kAccent,
          onChanged: (v) {
            ref.read(_d277SeatsProvider.notifier).state = v.round();
            ref.read(_d277QuoteSentProvider.notifier).state = false;
          },
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Included in bulk license',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              for (final item in const [
                'Admin dashboard + night-shift roster view',
                'Journey mode + SOS for all provisioned seats',
                'Monthly utilization report export (mock)',
                'SSO + audit log on Enterprise tier',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 14, color: ZapColors.safe),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: requesting || quoteSent
                ? null
                : () async {
                    ref.read(_d277RequestingProvider.notifier).state = true;
                    await Future<void>.delayed(
                      const Duration(milliseconds: 1200),
                    );
                    ref.read(_d277RequestingProvider.notifier).state = false;
                    ref.read(_d277QuoteSentProvider.notifier).state = true;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Quote sent for $seats seats · '
                            '${_formatInr(monthlyTotal)}/mo (mock).',
                          ),
                        ),
                      );
                    }
                  },
            icon: requesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    quoteSent
                        ? Icons.mark_email_read_rounded
                        : Icons.request_quote_rounded,
                    size: 16,
                  ),
            label: Text(
              quoteSent
                  ? 'Quote sent to sales'
                  : requesting
                      ? 'Sending quote…'
                      : 'Request bulk quote',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
          ),
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
    final tierIndex = ref.watch(_d277TierIndexProvider);
    final seats = ref.watch(_d277SeatsProvider);
    final quoteSent = ref.watch(_d277QuoteSentProvider);
    final payload = _enterprisePayload(
      tierIndex: tierIndex,
      allocatedSeats: seats,
      quoteSent: quoteSent,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.business_center_rounded,
          title: 'Enterprise B2B preview',
          subtitle:
              'Employer dashboard mock for night-shift bulk licenses · roster '
              'visibility · seat utilization · quote request flow.',
        ),
        const _PolicyRow(
          icon: Icons.nightlight_round,
          title: 'Night-shift focus',
          subtitle:
              'Designed for logistics, healthcare, and BPO employers who need '
              'journey tracking and SOS coverage for late-shift workers.',
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
              const SnackBar(content: Text('Enterprise B2B spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy enterprise spec'),
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
              label: const Text('Day 276 Reverse Image Search'),
              onPressed: () => context.push(AppRoutes.reverseImageSearch),
            ),
            ActionChip(
              label: const Text('Day 272 Insurance Partnership'),
              onPressed: () => context.push(AppRoutes.insurancePartnership),
            ),
            ActionChip(
              label: const Text('Day 228 SOS History'),
              onPressed: () => context.push(AppRoutes.sosHistoryTimeline),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _UtilizationChart extends StatelessWidget {
  const _UtilizationChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: 50,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value % 10 != 0) return const SizedBox.shrink();
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _kUtilLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _kUtilLabels[i],
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              color: _kAccent,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: _kAccent.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

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
