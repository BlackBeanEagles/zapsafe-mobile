/// Day 221 — Police Dashboard Overview
///
/// Section B (Days 221-240): victim-side police integration opt-in UI —
/// connection status, department card, last drill, and mock request form.
///
/// Tag: 🟡 MOCK-NOW — enterprise/gov feature; GET connection + POST request.
///
/// Route: [AppRoutes.policeDashboard] → `/police-dashboard`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum PoliceConnectionState { notConnected, pending, connected }

class PoliceConnectionInfo {
  final String departmentName;
  final String status;
  final DateTime connectedAt;
  final String? requestId;

  const PoliceConnectionInfo({
    required this.departmentName,
    required this.status,
    required this.connectedAt,
    this.requestId,
  });

  Map<String, dynamic> toJson() => {
        'connected': true,
        'department_name': departmentName,
        'connected_at': connectedAt.toUtc().toIso8601String(),
        'status': status,
        if (requestId != null) 'request_id': requestId,
      };
}

class PoliceDrillSummary {
  final DateTime completedAt;
  final int scoreDelta;
  final String departmentResponse;

  const PoliceDrillSummary({
    required this.completedAt,
    required this.scoreDelta,
    required this.departmentResponse,
  });
}

final _kMockConnected = PoliceConnectionInfo(
  departmentName: 'Mumbai Police Cyber Cell',
  status: 'active',
  connectedAt: DateTime.utc(2026, 8, 1),
);

final _kMockDrill = PoliceDrillSummary(
  completedAt: DateTime(2026, 5, 28, 14, 30, 0),
  scoreDelta: 8,
  departmentResponse: 'Acknowledged in 42s · reference MP-DRILL-8842',
);

const _kIndianStates = [
  ('MH', 'Maharashtra'),
  ('DL', 'Delhi'),
  ('KA', 'Karnataka'),
  ('TN', 'Tamil Nadu'),
  ('GJ', 'Gujarat'),
  ('WB', 'West Bengal'),
  ('RJ', 'Rajasthan'),
  ('UP', 'Uttar Pradesh'),
  ('TS', 'Telangana'),
  ('KL', 'Kerala'),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d221TabProvider = StateProvider<int>((ref) => 0);
final _d221ConnectionStateProvider = StateProvider<PoliceConnectionState>(
    (ref) => PoliceConnectionState.notConnected);
final _d221ConnectionInfoProvider =
    StateProvider<PoliceConnectionInfo?>((ref) => null);
final _d221SubmittingProvider = StateProvider<bool>((ref) => false);
final _d221SelectedStateProvider = StateProvider<String>((ref) => 'MH');
final _d221PendingRequestIdProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Overview', 'Request Connection', 'API Contract'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day221PoliceDashboardScreen extends ConsumerWidget {
  const Day221PoliceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d221TabProvider);
    final connectionState = ref.watch(_d221ConnectionStateProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 221 · Police Integration'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: _ConnectionChip(state: connectionState),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d221TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _OverviewTab(),
              1 => const _RequestTab(),
              _ => const _ApiContractTab(),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _submitRequest(
  WidgetRef ref, {
  required String city,
  required String stateCode,
  String? badgeNumber,
}) async {
  ref.read(_d221SubmittingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 900));
  ref.read(_d221SubmittingProvider.notifier).state = false;
  ref.read(_d221ConnectionStateProvider.notifier).state =
      PoliceConnectionState.pending;
  ref.read(_d221PendingRequestIdProvider.notifier).state = 'pol_123';
  ref.read(_d221ConnectionInfoProvider.notifier).state = PoliceConnectionInfo(
    departmentName: '$city Police — pending approval',
    status: 'pending',
    connectedAt: DateTime.now(),
    requestId: 'pol_123',
  );
}

void _simulateApproval(WidgetRef ref) {
  ref.read(_d221ConnectionStateProvider.notifier).state =
      PoliceConnectionState.connected;
  ref.read(_d221ConnectionInfoProvider.notifier).state = _kMockConnected;
  ref.read(_d221PendingRequestIdProvider.notifier).state = null;
}

void _resetDemo(WidgetRef ref) {
  ref.read(_d221ConnectionStateProvider.notifier).state =
      PoliceConnectionState.notConnected;
  ref.read(_d221ConnectionInfoProvider.notifier).state = null;
  ref.read(_d221PendingRequestIdProvider.notifier).state = null;
  ref.read(_d221SubmittingProvider.notifier).state = false;
}

// ── Tab 0: Overview ───────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d221ConnectionStateProvider);
    final info = ref.watch(_d221ConnectionInfoProvider);
    final requestId = ref.watch(_d221PendingRequestIdProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section B Day 1/20 · Settings → Safety → Police Integration',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.settings_rounded,
                  color: ZapColors.textMuted, size: 16),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Settings  ›  Safety  ›  Police Integration',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        switch (state) {
          PoliceConnectionState.notConnected => _NotConnectedCard(
              onRequest: () => ref.read(_d221TabProvider.notifier).state = 1,
            ),
          PoliceConnectionState.pending => _PendingCard(
              requestId: requestId ?? 'pol_123',
              info: info,
              onSimulateApproval: () => _simulateApproval(ref),
            ),
          PoliceConnectionState.connected => _ConnectedCard(info: info),
        },
        if (state == PoliceConnectionState.connected) ...[
          const SizedBox(height: ZapSpacing.lg),
          _LastDrillCard(drill: _kMockDrill),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.info.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'During SOS, dispatch status shows Received → Dispatched → '
                  'En route → Arrived with a reference number.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Semantics(
                  label: 'Open police dispatch status',
                  button: true,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.policeDispatchStatus),
                    icon: const Icon(Icons.timeline_rounded, size: 18),
                    label: const Text('Open dispatch status (Day 222)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ZapColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.xl),
        const Text(
          'Demo state',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Not connected'),
              onPressed: () => _resetDemo(ref),
            ),
            ActionChip(
              label: const Text('Pending'),
              onPressed: () {
                ref.read(_d221ConnectionStateProvider.notifier).state =
                    PoliceConnectionState.pending;
                ref.read(_d221PendingRequestIdProvider.notifier).state =
                    'pol_123';
                ref.read(_d221ConnectionInfoProvider.notifier).state =
                    PoliceConnectionInfo(
                  departmentName: 'Mumbai Police — pending approval',
                  status: 'pending',
                  connectedAt: DateTime.now(),
                  requestId: 'pol_123',
                );
              },
            ),
            ActionChip(
              label: const Text('Connected'),
              onPressed: () => _simulateApproval(ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotConnectedCard extends StatelessWidget {
  final VoidCallback onRequest;

  const _NotConnectedCard({required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              shape: BoxShape.circle,
              border: Border.all(color: ZapColors.border),
            ),
            child: const Icon(
              Icons.local_police_outlined,
              color: ZapColors.textMuted,
              size: 32,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Not connected',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Opt in to share SOS alerts with your local police department. '
            'Enterprise and government partnerships only — requires approval.',
            style: TextStyle(
              color: ZapColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.lg),
          Semantics(
            label: 'Request police connection',
            button: true,
            child: FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Request connection'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 75),
                backgroundColor: ZapColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final String requestId;
  final PoliceConnectionInfo? info;
  final VoidCallback onSimulateApproval;

  const _PendingCard({
    required this.requestId,
    required this.info,
    required this.onSimulateApproval,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top_rounded,
                  color: ZapColors.warning, size: 22),
              SizedBox(width: ZapSpacing.sm),
              Text(
                'Connection pending',
                style: TextStyle(
                  color: ZapColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            info?.departmentName ?? 'Awaiting department review',
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Request ID: $requestId · status: pending · 202 Accepted',
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Your city police department will verify eligibility (typically 24-48 hours). '
            'You\'ll receive a push when approved.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Semantics(
            label: 'Simulate department approval',
            button: true,
            child: OutlinedButton.icon(
              onPressed: onSimulateApproval,
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: const Text('Simulate approval (demo)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 75),
                foregroundColor: ZapColors.safe,
                side: const BorderSide(color: ZapColors.safe),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final PoliceConnectionInfo? info;

  const _ConnectedCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final data = info ?? _kMockConnected;
    final connectedLabel = '${data.connectedAt.day.toString().padLeft(2, '0')}/'
        '${data.connectedAt.month.toString().padLeft(2, '0')}/'
        '${data.connectedAt.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.12),
            ZapColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.safe.withOpacity(0.45), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_police_rounded,
                  color: ZapColors.safe,
                  size: 28,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connected',
                      style: TextStyle(
                        color: ZapColors.safe,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      data.departmentName,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
                ),
                child: Text(
                  data.status.toUpperCase(),
                  style: const TextStyle(
                    color: ZapColors.safe,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Divider(color: ZapColors.border, height: 1),
          const SizedBox(height: ZapSpacing.md),
          _MetaRow(label: 'Connected since', value: connectedLabel),
          const _MetaRow(
            label: 'SOS routing',
            value: 'Auto-notify on ALERT_ACTIVE',
          ),
          const _MetaRow(
            label: 'Evidence sharing',
            value: 'Hashes only · full vault on warrant',
          ),
        ],
      ),
    );
  }
}

class _LastDrillCard extends StatelessWidget {
  final PoliceDrillSummary drill;

  const _LastDrillCard({required this.drill});

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${drill.completedAt.day}/${drill.completedAt.month}/${drill.completedAt.year} '
        '· ${drill.completedAt.hour.toString().padLeft(2, '0')}:'
        '${drill.completedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fitness_center_rounded,
                  color: ZapColors.info, size: 18),
              SizedBox(width: ZapSpacing.sm),
              Text(
                'Last police drill',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            dateLabel,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Protection score +${drill.scoreDelta} · ${drill.departmentResponse}',
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Request ────────────────────────────────────────────────────────────
class _RequestTab extends ConsumerStatefulWidget {
  const _RequestTab();

  @override
  ConsumerState<_RequestTab> createState() => _RequestTabState();
}

class _RequestTabState extends ConsumerState<_RequestTab> {
  final _cityController = TextEditingController(text: 'Mumbai');
  final _badgeController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(_d221SubmittingProvider);
    final stateCode = ref.watch(_d221SelectedStateProvider);
    final connectionState = ref.watch(_d221ConnectionStateProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Request police connection',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        const Text(
          'POST /api/v1/police/connection/request/ · mock 202 response',
          style: TextStyle(
            color: ZapColors.textMuted,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        if (connectionState == PoliceConnectionState.connected) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
            ),
            child: const Text(
              'Already connected. Reset demo on Overview to submit a new request.',
              style: TextStyle(color: ZapColors.safe, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        TextField(
          controller: _cityController,
          style: const TextStyle(color: ZapColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'City *',
            labelStyle: const TextStyle(color: ZapColors.textMuted),
            filled: true,
            fillColor: ZapColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        DropdownButtonFormField<String>(
          value: stateCode,
          decoration: InputDecoration(
            labelText: 'State *',
            labelStyle: const TextStyle(color: ZapColors.textMuted),
            filled: true,
            fillColor: ZapColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
          dropdownColor: ZapColors.bgCard,
          style: const TextStyle(color: ZapColors.textPrimary),
          items: _kIndianStates
              .map(
                (s) => DropdownMenuItem(
                  value: s.$1,
                  child: Text('${s.$1} — ${s.$2}'),
                ),
              )
              .toList(),
          onChanged: connectionState == PoliceConnectionState.connected
              ? null
              : (v) {
                  if (v != null) {
                    ref.read(_d221SelectedStateProvider.notifier).state = v;
                  }
                },
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          controller: _badgeController,
          enabled: connectionState != PoliceConnectionState.connected,
          style: const TextStyle(color: ZapColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Badge / employee ID (optional)',
            labelStyle: const TextStyle(color: ZapColors.textMuted),
            hintText: 'For gov employees with pre-authorization',
            hintStyle:
                const TextStyle(color: ZapColors.textMuted, fontSize: 11),
            filled: true,
            fillColor: ZapColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Submit connection request',
          button: true,
          child: FilledButton.icon(
            onPressed: submitting ||
                    connectionState == PoliceConnectionState.connected ||
                    _cityController.text.trim().isEmpty
                ? null
                : () async {
                    await _submitRequest(
                      ref,
                      city: _cityController.text.trim(),
                      stateCode: stateCode,
                      badgeNumber: _badgeController.text.trim().isEmpty
                          ? null
                          : _badgeController.text.trim(),
                    );
                    if (!context.mounted) return;
                    ref.read(_d221TabProvider.notifier).state = 0;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request submitted — status pending'),
                      ),
                    );
                  },
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(submitting ? 'Submitting…' : 'Submit request'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.warning,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _previewRequestJson(
              city: _cityController.text.trim().isEmpty
                  ? 'Mumbai'
                  : _cityController.text.trim(),
              stateCode: stateCode,
              badge: _badgeController.text.trim(),
            ),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

String _previewRequestJson({
  required String city,
  required String stateCode,
  required String badge,
}) {
  final body = <String, dynamic>{
    'city': city,
    'state': stateCode,
    if (badge.isNotEmpty) 'badge_number': badge,
  };
  return const JsonEncoder.withIndent('  ').convert(body);
}

// ── Tab 2: API Contract ───────────────────────────────────────────────────────
class _ApiContractTab extends ConsumerWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_d221ConnectionInfoProvider);
    final getResponse = info != null && info.status == 'active'
        ? const JsonEncoder.withIndent('  ').convert(info.toJson())
        : '''{
  "connected": false,
  "department_name": null,
  "connected_at": null,
  "status": "none"
}''';

    const postRequest = '''{
  "city": "Mumbai",
  "state": "MH"
}''';

    const postResponse = '''{
  "request_id": "pol_123",
  "status": "pending"
}''';

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _EndpointCard(
          method: 'GET',
          path: '/api/v1/police/connection/',
          description: 'Current police integration status for logged-in user.',
          sample: getResponse,
        ),
        const SizedBox(height: ZapSpacing.md),
        const _EndpointCard(
          method: 'POST',
          path: '/api/v1/police/connection/request/',
          description: 'Submit opt-in request · returns 202 Accepted.',
          sample: '$postRequest\n\n// Response 202\n$postResponse',
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy API contracts',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              final text = 'GET /api/v1/police/connection/\n$getResponse\n\n'
                  'POST /api/v1/police/connection/request/\n$postRequest';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API contracts copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy contracts'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
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
            'Tomorrow: Day 224 — Referral invite a friend.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EndpointCard extends StatelessWidget {
  final String method;
  final String path;
  final String description;
  final String sample;

  const _EndpointCard({
    required this.method,
    required this.path,
    required this.description,
    required this.sample,
  });

  @override
  Widget build(BuildContext context) {
    final methodColor = method == 'GET' ? ZapColors.info : ZapColors.warning;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method,
                  style: TextStyle(
                    color: methodColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  path,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          SelectableText(
            sample,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  final PoliceConnectionState state;

  const _ConnectionChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      PoliceConnectionState.notConnected => ('Offline', ZapColors.textMuted),
      PoliceConnectionState.pending => ('Pending', ZapColors.warning),
      PoliceConnectionState.connected => ('Connected', ZapColors.safe),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
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
