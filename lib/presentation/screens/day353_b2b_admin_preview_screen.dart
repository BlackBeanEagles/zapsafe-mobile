/// Day 353 — B2B Admin Portal Preview
///
/// Mock employer/org-admin console: org users list, SOS count, response
/// SLA metric. Distinct from Day 277's night-shift roster/bulk-license
/// mock (`day277_enterprise_b2b_preview_screen.dart` — seat allocation,
/// utilization chart) — this screen is the admin-console angle the Day
/// 351-360 spec asks for: a table of org users + safety KPIs, not a
/// licensing/quote flow.
///
/// Verified against `zapsafe_backend` before building: grepped `org`,
/// `tenant`, `enterprise`, `company`, and `business` across every app —
/// no org/tenant model exists anywhere. The two `tenant` hits are just
/// comments (`sos/models.py`: "Per-tenant deployments can ship this
/// table..."; `settings.py`: "...per-tenant key isolation" describing a
/// future KMS feature, not a real multi-tenant model). ZapSafe today is
/// entirely single-user/consumer — there is no concept of an
/// organization owning multiple user accounts anywhere in the schema.
/// This screen is a realistic-structure mock, never presented as live.
///
/// Proposed contract (not implemented anywhere yet):
///   GET /api/v1/enterprise/org/{org_id}/users/
///     -> {"count", "users": [{"id","name","phone","last_sos_at","status"}]}
///   GET /api/v1/enterprise/org/{org_id}/metrics/
///     -> {"sos_count_30d","avg_response_sla_secs","sla_target_secs"}
///
/// Tag: 🟡 MOCK-NOW · no org/tenant model exists in zapsafe_backend.
///
/// Route: [AppRoutes.b2bAdminPreview] → `/day-353-b2b-admin-preview`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _OrgUser {
  const _OrgUser({
    required this.name,
    required this.role,
    required this.lastSosAt,
    required this.status,
    required this.responseSecs,
  });

  final String name;
  final String role;
  final String? lastSosAt;
  final String status; // active | inactive
  final int? responseSecs;
}

const _kOrgUsers = [
  _OrgUser(
    name: 'Ananya Rao',
    role: 'Warehouse Picker',
    lastSosAt: '2026-08-05 · 23:12 IST',
    status: 'active',
    responseSecs: 38,
  ),
  _OrgUser(
    name: 'Priya Sundaram',
    role: 'Dispatcher',
    lastSosAt: null,
    status: 'active',
    responseSecs: null,
  ),
  _OrgUser(
    name: 'Meera Kapoor',
    role: 'Driver',
    lastSosAt: '2026-07-29 · 01:47 IST',
    status: 'active',
    responseSecs: 52,
  ),
  _OrgUser(
    name: 'Sneha Verma',
    role: 'Supervisor',
    lastSosAt: null,
    status: 'active',
    responseSecs: null,
  ),
  _OrgUser(
    name: 'Kavya Nair',
    role: 'Picker',
    lastSosAt: '2026-06-30 · 19:05 IST',
    status: 'inactive',
    responseSecs: 71,
  ),
];

int get _sosCount30d => _kOrgUsers.where((u) => u.lastSosAt != null).length;
double get _avgResponseSecs {
  final withResponse = _kOrgUsers.where((u) => u.responseSecs != null).toList();
  if (withResponse.isEmpty) return 0;
  return withResponse.map((u) => u.responseSecs!).reduce((a, b) => a + b) / withResponse.length;
}

const _kSlaTargetSecs = 60;

Map<String, dynamic> _orgPayload() => {
      'endpoint': 'GET /api/v1/enterprise/org/{org_id}/users/ (proposed, not implemented)',
      'count': _kOrgUsers.length,
      'sos_count_30d': _sosCount30d,
      'avg_response_sla_secs': _avgResponseSecs.round(),
      'sla_target_secs': _kSlaTargetSecs,
      'sla_met': _avgResponseSecs <= _kSlaTargetSecs,
    };

class Day353B2bAdminPreviewScreen extends ConsumerWidget {
  const Day353B2bAdminPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaMet = _avgResponseSecs <= _kSlaTargetSecs;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.b2b_admin_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded, color: ZapColors.warning, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🟡 MOCK-NOW · Section K Day 3/10 · verified zapsafe_backend has '
                    'no org/tenant model — ZapSafe is entirely single-user/consumer '
                    'today. Every row below is realistic-structure mock data, never '
                    'live.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.b2b_admin_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          const Text('Nova Logistics Pvt Ltd · Org admin console',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 13)),
          const SizedBox(height: ZapSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _KpiTile(
                  label: 'Org users',
                  value: '${_kOrgUsers.length}',
                  color: ZapColors.info,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: _KpiTile(
                  label: 'SOS (30d)',
                  value: '$_sosCount30d',
                  color: ZapColors.danger,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: _KpiTile(
                  label: 'Avg response SLA',
                  value: '${_avgResponseSecs.round()}s',
                  color: slaMet ? ZapColors.safe : ZapColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Row(
              children: [
                Icon(
                  slaMet ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: slaMet ? ZapColors.safe : ZapColors.warning,
                  size: 18,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'SLA target: response within ${_kSlaTargetSecs}s · '
                    '${slaMet ? "met" : "missed"} this period',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('ORG USERS', style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final u in _kOrgUsers)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: (u.status == 'active' ? ZapColors.safe : ZapColors.textMuted)
                        .withOpacity(0.15),
                    child: Text(u.name.substring(0, 1),
                        style: TextStyle(
                            color: u.status == 'active' ? ZapColors.safe : ZapColors.textMuted,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name,
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                        Text(
                          '${u.role} · ${u.lastSosAt ?? "No SOS on record"}',
                          style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ZapBadge(
                    label: u.status == 'active' ? 'ACTIVE' : 'INACTIVE',
                    intent: u.status == 'active' ? ZapBadgeIntent.safe : ZapBadgeIntent.neutral,
                    size: ZapBadgeSize.small,
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.xl),
          Text('PROPOSED CONTRACT (NOT IMPLEMENTED)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: SelectableText(
              _kJsonEncoder.convert(_orgPayload()),
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Copy org payload',
            icon: Icons.copy_rounded,
            fullWidth: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_orgPayload())));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Org payload copied')));
            },
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapButton.tonal(
            label: 'Open Day 277 licenses & roster preview',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.enterpriseB2bPreview),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.3),
      child: Column(
        children: [
          Text(value, style: ZapTypography.headlineMedium.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: ZapTypography.labelSmall.copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}
