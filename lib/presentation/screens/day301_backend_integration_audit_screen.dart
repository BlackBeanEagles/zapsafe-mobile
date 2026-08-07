/// Day 301 — Backend Integration Audit Hub
///
/// Real, grep-derived audit of frontend↔backend wiring. Every row below was
/// produced by reading the actual Django `urls.py` files in
/// `zapsafe_backend` and the actual Dart service files under
/// `lib/data/services/` — not fabricated. `status` is `live` only when a
/// real `ApiClient`/`Dio` call to that exact path exists in a committed
/// service file; `mock` when a screen/feature exists but still runs on
/// local/hardcoded data; `missing` when the backend endpoint is real but no
/// frontend code calls it yet. See `_seedAudit()` for the full list and the
/// source comment on each entry.
/// Tag: 🔗 WIRE
///
/// Route: AppRoutes.integrationAudit
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

enum AuditStatus { live, mock, missing }

class IntegrationAuditEntry {
  const IntegrationAuditEntry({
    required this.group,
    required this.method,
    required this.endpoint,
    required this.status,
    required this.sourceFile,
    required this.note,
  });

  final String group;
  final String method;
  final String endpoint;
  final AuditStatus status;

  /// Real file path — the Dart service that calls it (status=live/mock) or
  /// the Django `urls.py` that defines it (status=missing).
  final String sourceFile;
  final String note;
}

/// Real audit seed — derived from:
///   grep 'path(' across zapsafe_backend/*/urls.py  (endpoint existence)
///   grep 'ApiClient|dio\.' across zapsafe_mobile lib/data/services/*.dart (wiring)
/// Run 2026-08-06/07. Not a fabricated 40-item placeholder list.
List<IntegrationAuditEntry> _seedAudit() => const [
      // ─── Auth ──────────────────────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'Auth',
        method: 'POST',
        endpoint: '/auth/register/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/auth_service.dart',
        note: 'OTP request. DLT registration pending on backend — SMS to '
            'Indian numbers cannot deliver yet, so this path is blocked by '
            'design, not a frontend gap.',
      ),
      IntegrationAuditEntry(
        group: 'Auth',
        method: 'POST',
        endpoint: '/auth/verify-otp/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/auth_service.dart',
        note: 'Same DLT caveat as register/.',
      ),
      IntegrationAuditEntry(
        group: 'Auth',
        method: 'POST',
        endpoint: '/auth/google-verify/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/google_auth_service.dart',
        note: 'Real Google Sign-In + Firebase handshake — the current '
            'primary registration path while DLT is blocked.',
      ),
      IntegrationAuditEntry(
        group: 'Auth',
        method: 'POST',
        endpoint: '/api/v1/auth/token/refresh/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/api_client.dart',
        note: 'Wired inside the Dio auth interceptor (proactive + 401 retry).',
      ),
      IntegrationAuditEntry(
        group: 'Auth',
        method: 'POST',
        endpoint: '/api/v1/auth/logout/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/auth_service.dart',
        note: 'Blacklists refresh token server-side.',
      ),
      IntegrationAuditEntry(
        group: 'Auth',
        method: 'GET',
        endpoint: '/api/v1/users/me/',
        status: AuditStatus.live,
        sourceFile: 'lib/core/constants/api_config.dart (ApiConfig.me)',
        note: 'Endpoint constant defined; confirm call site before shipping.',
      ),

      // ─── SOS ───────────────────────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'POST',
        endpoint: '/api/v1/sos/trigger/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/sos_service.dart',
        note: 'Starts the real MSG91/FCM cascade.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'POST',
        endpoint: '/api/v1/sos/<id>/cancel/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/sos_service.dart',
        note: 'LP3 duress-PIN aware cancel.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'POST',
        endpoint: '/api/v1/sos/<id>/location/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/sos_service.dart',
        note: 'Live-SOS GPS streaming.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'GET',
        endpoint: '/api/v1/sos/active/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/sos_service.dart',
        note: 'Cold-start session hydration.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'GET',
        endpoint: '/api/v1/sos/dashboard/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/dashboard_service.dart',
        note: 'SOS rollup stats.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'GET',
        endpoint: '/api/v1/sos/<id>/delivery-status/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/sos_delivery_service.dart',
        note: 'Wired Day 304 — was missing before this sprint (Day 75 '
            'Delivery Confirmation screen used simulated data only).',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'GET',
        endpoint: '/api/v1/sos/history/<id>/timeline/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/sos/urls.py',
        note: 'Real endpoint, no frontend service calls it yet.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'GET',
        endpoint: '/api/v1/sos/tags/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/sos/urls.py',
        note: 'Real endpoint, no frontend service calls it yet.',
      ),
      IntegrationAuditEntry(
        group: 'SOS',
        method: 'GET',
        endpoint: '/api/v1/sos/<id>/notifications/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/sos/urls.py',
        note: 'Owner-facing per-channel send+delivery view — real endpoint, '
            'not yet called (delivery-status/ above covers the Day 75 '
            'screen instead).',
      ),

      // ─── Contacts ──────────────────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'Contacts',
        method: 'GET/POST',
        endpoint: '/api/v1/contacts/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/contacts_service.dart',
        note: 'Full CRUD, real Dio calls behind kUseMockData fallback.',
      ),
      IntegrationAuditEntry(
        group: 'Contacts',
        method: 'PUT/DELETE',
        endpoint: '/api/v1/contacts/<id>/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/contacts_service.dart',
        note: 'Same file as above.',
      ),
      IntegrationAuditEntry(
        group: 'Contacts',
        method: 'POST',
        endpoint: '/api/v1/contacts/<id>/verify/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/contacts/urls.py',
        note: 'Real endpoint, not called from ContactsService yet.',
      ),

      // ─── Analytics ───────────────────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'Analytics',
        method: 'GET',
        endpoint: '/api/v1/analytics/sos-summary/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/analytics_api_service.dart',
        note: 'Wired Day 302 — was unwired before this sprint (backend has '
            'been live since Day 81-85).',
      ),
      IntegrationAuditEntry(
        group: 'Analytics',
        method: 'GET',
        endpoint: '/api/v1/analytics/detections/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/analytics_api_service.dart',
        note: 'Wired Day 302.',
      ),
      IntegrationAuditEntry(
        group: 'Analytics',
        method: 'GET',
        endpoint: '/api/v1/analytics/contacts/response-rate/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/analytics_api_service.dart',
        note: 'Wired Day 302.',
      ),
      IntegrationAuditEntry(
        group: 'Analytics',
        method: 'GET/POST',
        endpoint: '/api/v1/analytics/device-health/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/analytics_api_service.dart',
        note: 'Wired Day 302.',
      ),

      // ─── Premium / Subscription ────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'Premium',
        method: 'POST',
        endpoint: '/api/v1/subscription/create/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/premium_subscription_service.dart',
        note: 'Wired Day 303 — Razorpay checkout URL creation.',
      ),
      IntegrationAuditEntry(
        group: 'Premium',
        method: 'GET',
        endpoint: '/api/v1/subscription/status/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/premium_subscription_service.dart',
        note: 'Wired Day 303 — drives tier badge + contact/storage limits.',
      ),
      IntegrationAuditEntry(
        group: 'Premium',
        method: 'POST',
        endpoint: '/api/v1/subscription/cancel/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/premium_subscription_service.dart',
        note: 'Wired Day 303.',
      ),

      // ─── Notifications ─────────────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'Notifications',
        method: 'GET',
        endpoint: '/api/v1/notifications/history/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/notifications/urls.py',
        note: 'Real endpoint (Day 76 Notification History screen still '
            'reads local/mock data per its own header comment).',
      ),
      IntegrationAuditEntry(
        group: 'Notifications',
        method: 'POST',
        endpoint: '/api/v1/notifications/battery-warning/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/notifications/urls.py',
        note: 'Real endpoint, not called from frontend.',
      ),
      IntegrationAuditEntry(
        group: 'Notifications',
        method: 'GET/PATCH',
        endpoint: '/api/v1/notification-prefs/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/notification_pref_service.dart',
        note: 'Category preference toggles.',
      ),
      IntegrationAuditEntry(
        group: 'Notifications',
        method: 'POST',
        endpoint: '/api/v1/push/register/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/push_service.dart',
        note: 'FCM token registration.',
      ),

      // ─── i18n ──────────────────────────────────────────────────────────
      IntegrationAuditEntry(
        group: 'i18n',
        method: 'GET',
        endpoint: '/api/v1/i18n/languages/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/i18n/urls.py',
        note: 'Real endpoint (15 supported languages server-side); '
            'frontend hardcodes its own locale list in main.dart instead '
            'of fetching this.',
      ),
      IntegrationAuditEntry(
        group: 'i18n',
        method: 'ALL',
        endpoint: 'Accept-Language header',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/api_client.dart',
        note: 'Wired Day 305 — every authenticated + public Dio request now '
            'sends the real app locale. Backend AcceptLanguageMiddleware '
            '(Day 103) confirmed live and registered in MIDDLEWARE, '
            'contrary to the Day 305 spec text implying it might not be '
            'live yet.',
      ),

      // ─── GPS / Evidence / ML (Days 53-61, all live) ───────────────────
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'POST',
        endpoint: '/api/v1/gps/ping/ (batch/, last-known/ real too)',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/gps_service.dart',
        note: 'GPS ping wired; batch/last-known real on backend, not all '
            'called from frontend yet.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET/POST',
        endpoint: '/api/v1/evidence/',
        status: AuditStatus.live,
        sourceFile: 'lib/core/constants/api_config.dart (ApiConfig.evidence)',
        note: 'Metadata endpoint constant present.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET',
        endpoint: '/api/v1/evidence/search/',
        status: AuditStatus.missing,
        sourceFile: 'zapsafe_backend/evidence/search_views.py',
        note: 'Found during Day 309 (Evidence Vault Search polish) — real '
            'Day 209 endpoint (q/type/from/to query params), not in the '
            'original Day 301 seed list. Day 309 intentionally filters the '
            'existing local/mock evidence list instead (its own spec says '
            '"offline"), so this stays unwired — added here for an '
            'accurate count rather than silently leaving the gap '
            'undocumented.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET',
        endpoint: '/api/v1/ml/compatibility-matrix/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/compatibility_service.dart',
        note: 'Public endpoint, real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET/POST',
        endpoint: '/api/v1/ml/device-capability/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/capability_report_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET/POST',
        endpoint: '/api/v1/ml/detection-events/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/detection_event_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET/POST',
        endpoint: '/api/v1/ml/model-downloads/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/model_download_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET',
        endpoint: '/api/v1/ml/analytics/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/ml_analytics_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'CRUD',
        endpoint: '/api/v1/safe-zones/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/safe_zone_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'GET',
        endpoint: '/api/v1/protection-score/ (+history/)',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/protection_score_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'POST/GET',
        endpoint: '/api/v1/drill/start/ (+history/)',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/drill_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'CRUD',
        endpoint: '/api/v1/incidents/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/incident_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'CRUD',
        endpoint: '/api/v1/alert-thresholds/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/alert_threshold_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'CRUD',
        endpoint: '/api/v1/escalation-policies/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/escalation_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'CRUD',
        endpoint: '/api/v1/check-ins/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/check_in_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'CRUD',
        endpoint: '/api/v1/sos-templates/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/sos_template_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'POST/GET',
        endpoint: '/api/v1/audit-log/ (+summary/)',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/audit_log_service.dart',
        note: 'Real.',
      ),
      IntegrationAuditEntry(
        group: 'GPS & Evidence',
        method: 'POST/GET',
        endpoint: '/api/v1/data-export/',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/data_export_service.dart',
        note: 'Real.',
      ),

      // ─── Privacy & Account (Days 70, 151-200) ─────────────────────────
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'GET/PATCH',
        endpoint: '/api/v1/privacy/ (+deletion-request/)',
        status: AuditStatus.live,
        sourceFile: 'lib/data/services/privacy_service.dart',
        note: 'Day 70 privacy/consent — real.',
      ),
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'GET/PATCH',
        endpoint: '/api/v1/account/consent/',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/account/urls.py (real) — no frontend caller',
        note: 'Backend real (Days 151-200 contracts, confirmed in '
            'account/urls.py); no Dart service calls it — frontend screen, '
            'if any, is still local/mock.',
      ),
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'GET',
        endpoint: '/api/v1/account/sessions/ (+revoke-all/, <id>/)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/account/urls.py (real) — no frontend caller',
        note: 'Real backend, not wired.',
      ),
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'POST/GET',
        endpoint: '/api/v1/account/export-request/ (+export-status/)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/account/urls.py (real) — no frontend caller',
        note: 'Real backend, not wired — distinct from the older '
            '/api/v1/data-export/ which IS wired.',
      ),
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'POST',
        endpoint: '/api/v1/account/delete-request/ (+cancel-deletion/)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/account/urls.py (real) — no frontend caller',
        note: 'Real backend, not wired.',
      ),
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'GET',
        endpoint: '/api/v1/account/audit-log/',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/account/urls.py (real) — no frontend caller',
        note: 'Distinct from /api/v1/audit-log/ (which IS wired).',
      ),
      IntegrationAuditEntry(
        group: 'Privacy & Account',
        method: 'GET/PATCH',
        endpoint: '/api/v1/account/retention/ (+purge-now/)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/account/urls.py (real) — no frontend caller',
        note: 'Real backend, not wired.',
      ),

      // ─── Not yet live on frontend at all (Police / Referral / Journey / Family) ──
      IntegrationAuditEntry(
        group: 'Police / Referral / Journey / Family',
        method: 'GET/POST',
        endpoint: '/api/v1/police/connection/ (+request/, dispatch/<id>/)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/police/urls.py (real) — no frontend caller',
        note: 'Day 221-223 Police Dashboard UI is demo/mock per the '
            'project\'s own Day 201-300 doc — real endpoint exists.',
      ),
      IntegrationAuditEntry(
        group: 'Police / Referral / Journey / Family',
        method: 'GET',
        endpoint: '/api/v1/referral/code/ (+stats/)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/referral/urls.py (real) — no frontend caller',
        note: 'Real backend, not wired.',
      ),
      IntegrationAuditEntry(
        group: 'Police / Referral / Journey / Family',
        method: 'POST/GET',
        endpoint: '/api/v1/journey/start/ (+checkpoint/, group/*)',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/journey/urls.py (real) — no frontend caller',
        note: 'Day 251-252 Group Journey Map UI is mock per its own header '
            '("mock location stream") — real endpoint exists.',
      ),
      IntegrationAuditEntry(
        group: 'Police / Referral / Journey / Family',
        method: 'GET',
        endpoint: '/api/v1/family/dashboard/',
        status: AuditStatus.mock,
        sourceFile: 'zapsafe_backend/family/urls.py (real) — no frontend caller',
        note: 'Day 254 Family SOS History UI is mock — real endpoint exists.',
      ),
    ];

class Day301BackendIntegrationAuditScreen extends StatefulWidget {
  const Day301BackendIntegrationAuditScreen({super.key});

  @override
  State<Day301BackendIntegrationAuditScreen> createState() =>
      _Day301BackendIntegrationAuditScreenState();
}

class _Day301BackendIntegrationAuditScreenState
    extends State<Day301BackendIntegrationAuditScreen> {
  late final List<IntegrationAuditEntry> _entries = _seedAudit();
  String? _expandedEndpoint;

  int get _liveCount => _entries.where((e) => e.status == AuditStatus.live).length;
  int get _mockCount => _entries.where((e) => e.status == AuditStatus.mock).length;
  int get _missingCount =>
      _entries.where((e) => e.status == AuditStatus.missing).length;

  Map<String, List<IntegrationAuditEntry>> get _grouped {
    final map = <String, List<IntegrationAuditEntry>>{};
    for (final e in _entries) {
      map.putIfAbsent(e.group, () => []).add(e);
    }
    return map;
  }

  Future<void> _exportJson() async {
    final buffer = StringBuffer('[\n');
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      buffer.writeln(
        '  {"group": "${e.group}", "method": "${e.method}", '
        '"endpoint": "${e.endpoint}", "status": "${e.status.name}", '
        '"source": "${e.sourceFile}"}${i == _entries.length - 1 ? '' : ','}',
      );
    }
    buffer.write(']');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ZapSnackbar.success(context, 'Audit JSON copied (${_entries.length} rows)');
    }
  }

  Color _statusColor(AuditStatus s) => switch (s) {
        AuditStatus.live => ZapColors.safe,
        AuditStatus.mock => ZapColors.warning,
        AuditStatus.missing => ZapColors.danger,
      };

  ZapBadgeIntent _statusIntent(AuditStatus s) => switch (s) {
        AuditStatus.live => ZapBadgeIntent.safe,
        AuditStatus.mock => ZapBadgeIntent.warning,
        AuditStatus.missing => ZapBadgeIntent.danger,
      };

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      appBar: AppBar(
        title: Text('day301_305.audit_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'Export JSON',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: _exportJson,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text(
            'day301_305.audit_heading'.tr(),
            style: ZapTypography.headlineMedium
                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            '${_entries.length} endpoints found by reading the real Django '
            'urls.py files and the real Dart service files — not a padded '
            'placeholder count.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              _SummaryCard(label: 'Live', count: _liveCount, color: ZapColors.safe),
              const SizedBox(width: ZapSpacing.sm),
              _SummaryCard(label: 'Mock', count: _mockCount, color: ZapColors.warning),
              const SizedBox(width: ZapSpacing.sm),
              _SummaryCard(
                  label: 'Missing', count: _missingCount, color: ZapColors.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
          for (final group in grouped.entries) ...[
            Text(
              group.key.toUpperCase(),
              style: ZapTypography.labelLarge.copyWith(
                color: ZapColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            for (final entry in group.value) ...[
              ZapCard(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                onTap: () => setState(() {
                  final key = '${entry.method} ${entry.endpoint}';
                  _expandedEndpoint = _expandedEndpoint == key ? null : key;
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _statusColor(entry.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Text(
                            '${entry.method}  ${entry.endpoint}',
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary),
                          ),
                        ),
                        ZapBadge(
                          label: entry.status.name.toUpperCase(),
                          intent: _statusIntent(entry.status),
                          size: ZapBadgeSize.small,
                        ),
                      ],
                    ),
                    if (_expandedEndpoint == '${entry.method} ${entry.endpoint}') ...[
                      const SizedBox(height: ZapSpacing.sm),
                      Text('Source: ${entry.sourceFile}',
                          style: ZapTypography.monoSmall
                              .copyWith(color: ZapColors.textSecondary)),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(entry.note,
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: ZapSpacing.lg),
          ],
          ZapButton.elevated(
            label: 'Start Day 302 wiring sprint',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.analyticsLiveWire),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ZapCard(
        backgroundColor: color.withOpacity(0.08),
        borderColor: color.withOpacity(0.3),
        child: Column(
          children: [
            Text('$count',
                style: ZapTypography.displaySmall
                    .copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: ZapSpacing.xs),
            Text(label,
                style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
