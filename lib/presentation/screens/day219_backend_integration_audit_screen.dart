/// Day 219 — Backend Integration Audit Matrix
///
/// Section A (Days 201-220): searchable matrix of ~50 API contracts with
/// live / mock / missing status, JSON samples, and health endpoint ping.
///
/// Tag: 🟡 MOCK-NOW — backend catch-up tracker; pings GET /api/v1/health/ when available.
///
/// Route: [AppRoutes.backendIntegrationAudit] → `/backend-integration-audit`
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_config.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum ApiWireStatus { live, mock, missing }

extension ApiWireStatusX on ApiWireStatus {
  String get label => switch (this) {
        ApiWireStatus.live => 'Live',
        ApiWireStatus.mock => 'Mock',
        ApiWireStatus.missing => 'Missing',
      };

  Color get color => switch (this) {
        ApiWireStatus.live => ZapColors.safe,
        ApiWireStatus.mock => ZapColors.warning,
        ApiWireStatus.missing => ZapColors.danger,
      };
}

enum ApiCategory {
  all,
  auth,
  sos,
  ml,
  user,
  privacy,
  billing,
  missing,
}

extension ApiCategoryX on ApiCategory {
  String get label => switch (this) {
        ApiCategory.all => 'All',
        ApiCategory.auth => 'Auth',
        ApiCategory.sos => 'SOS',
        ApiCategory.ml => 'ML',
        ApiCategory.user => 'User',
        ApiCategory.privacy => 'Privacy',
        ApiCategory.billing => 'Billing',
        ApiCategory.missing => 'Missing',
      };
}

class ApiContractRow {
  final String id;
  final String method;
  final String path;
  final String usedBy;
  final ApiWireStatus status;
  final ApiCategory category;
  final String sampleJson;

  const ApiContractRow({
    required this.id,
    required this.method,
    required this.path,
    required this.usedBy,
    required this.status,
    required this.category,
    required this.sampleJson,
  });
}

enum HealthPingState { idle, loading, ok, error }

// ── ~50 API contracts ─────────────────────────────────────────────────────────
const _kContracts = [
  ApiContractRow(
    id: 'health',
    method: 'GET',
    path: '/api/v1/health/',
    usedBy: 'Day 219 · startup probe',
    status: ApiWireStatus.live,
    category: ApiCategory.auth,
    sampleJson: '{"status":"ok","version":"0.5.6","db":"connected"}',
  ),
  ApiContractRow(
    id: 'auth_register',
    method: 'POST',
    path: '/auth/register/',
    usedBy: 'Day 6 · OTP request',
    status: ApiWireStatus.live,
    category: ApiCategory.auth,
    sampleJson: '{"phone":"+919876543210","channel":"sms"}',
  ),
  ApiContractRow(
    id: 'auth_verify',
    method: 'POST',
    path: '/auth/verify-otp/',
    usedBy: 'Day 6 · OTP verify',
    status: ApiWireStatus.live,
    category: ApiCategory.auth,
    sampleJson: '{"phone":"+919876543210","otp":"123456"}',
  ),
  ApiContractRow(
    id: 'token_refresh',
    method: 'POST',
    path: '/api/v1/auth/token/refresh/',
    usedBy: 'Day 9 · JWT refresh',
    status: ApiWireStatus.live,
    category: ApiCategory.auth,
    sampleJson: '{"refresh":"<jwt>"}',
  ),
  ApiContractRow(
    id: 'auth_logout',
    method: 'POST',
    path: '/api/v1/auth/logout/',
    usedBy: 'Day 81 · sign out',
    status: ApiWireStatus.mock,
    category: ApiCategory.auth,
    sampleJson: '{"refresh":"<jwt>"}',
  ),
  ApiContractRow(
    id: 'users_me',
    method: 'GET',
    path: '/api/v1/users/me/',
    usedBy: 'Day 81 · profile',
    status: ApiWireStatus.live,
    category: ApiCategory.user,
    sampleJson: '{"id":"uuid","name":"Priya","phone":"+919876543210"}',
  ),
  ApiContractRow(
    id: 'contacts_list',
    method: 'GET',
    path: '/api/v1/contacts/',
    usedBy: 'Day 83 · contacts v2',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"results":[{"id":"c1","name":"Amma","tier":1}]}',
  ),
  ApiContractRow(
    id: 'contacts_create',
    method: 'POST',
    path: '/api/v1/contacts/',
    usedBy: 'Day 83 · add contact',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"name":"Amma","phone":"+919811122233","tier":1}',
  ),
  ApiContractRow(
    id: 'sos_trigger',
    method: 'POST',
    path: '/api/v1/sos/trigger/',
    usedBy: 'Day 38 · SOS active',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"lat":12.97,"lng":77.59,"trigger":"manual"}',
  ),
  ApiContractRow(
    id: 'sos_cancel',
    method: 'POST',
    path: '/api/v1/sos/cancel/',
    usedBy: 'Day 38 · cancel SOS',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"sos_id":"uuid","reason":"false_alarm"}',
  ),
  ApiContractRow(
    id: 'gps_ping',
    method: 'POST',
    path: '/api/v1/gps/ping/',
    usedBy: 'Day 36 · location stream',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"lat":12.97,"lng":77.59,"accuracy_m":8.2}',
  ),
  ApiContractRow(
    id: 'evidence_list',
    method: 'GET',
    path: '/api/v1/evidence/',
    usedBy: 'Day 82 · vault',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"results":[{"id":"e1","type":"audio","duration_s":12}]}',
  ),
  ApiContractRow(
    id: 'evidence_upload',
    method: 'POST',
    path: '/api/v1/evidence/',
    usedBy: 'Day 82 · vault upload',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"sos_id":"uuid","mime":"audio/wav","size_bytes":48000}',
  ),
  ApiContractRow(
    id: 'compat_matrix',
    method: 'GET',
    path: '/api/v1/ml/compatibility-matrix/',
    usedBy: 'Day 53 · phone capability',
    status: ApiWireStatus.live,
    category: ApiCategory.ml,
    sampleJson: '{"tiers":[{"name":"HIGH","min_ram_mb":4096}]}',
  ),
  ApiContractRow(
    id: 'device_capability',
    method: 'POST',
    path: '/api/v1/ml/device-capability/',
    usedBy: 'Day 54 · capability report',
    status: ApiWireStatus.mock,
    category: ApiCategory.ml,
    sampleJson: '{"tier":"HIGH","sensors":["gps","imu","mic"]}',
  ),
  ApiContractRow(
    id: 'detection_events',
    method: 'POST',
    path: '/api/v1/ml/detection-events/',
    usedBy: 'Day 55 · DCS events',
    status: ApiWireStatus.mock,
    category: ApiCategory.ml,
    sampleJson: '{"model":"M1","confidence":0.91,"dcs":0.72}',
  ),
  ApiContractRow(
    id: 'model_downloads',
    method: 'POST',
    path: '/api/v1/ml/model-downloads/',
    usedBy: 'Day 56 · model install',
    status: ApiWireStatus.mock,
    category: ApiCategory.ml,
    sampleJson: '{"model_type":"scream","sha256_verified":true}',
  ),
  ApiContractRow(
    id: 'ml_analytics',
    method: 'GET',
    path: '/api/v1/ml/analytics/',
    usedBy: 'Day 57 · ML dashboard',
    status: ApiWireStatus.mock,
    category: ApiCategory.ml,
    sampleJson: '{"inferences_24h":142,"avg_latency_ms":38}',
  ),
  ApiContractRow(
    id: 'safe_zones',
    method: 'GET',
    path: '/api/v1/safe-zones/',
    usedBy: 'Day 58 · safe zones',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"results":[{"name":"Home","radius_m":120}]}',
  ),
  ApiContractRow(
    id: 'protection_score',
    method: 'GET',
    path: '/api/v1/protection-score/',
    usedBy: 'Day 59 · score ring',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"score":78,"components":{"contacts":25,"drill":10}}',
  ),
  ApiContractRow(
    id: 'protection_history',
    method: 'GET',
    path: '/api/v1/protection-score/history/',
    usedBy: 'Day 59 · 30-day chart',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"days":[{"date":"2026-06-01","score":72}]}',
  ),
  ApiContractRow(
    id: 'drill_start',
    method: 'POST',
    path: '/api/v1/drill/start/',
    usedBy: 'Day 60 · emergency drill',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"tier_contacts_only":true}',
  ),
  ApiContractRow(
    id: 'drill_history',
    method: 'GET',
    path: '/api/v1/drill/history/',
    usedBy: 'Day 60 · drill log',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"results":[{"id":"d1","score_delta":+8}]}',
  ),
  ApiContractRow(
    id: 'inference_logs',
    method: 'POST',
    path: '/api/v1/ml/inference-logs/',
    usedBy: 'Day 61 · inference log',
    status: ApiWireStatus.mock,
    category: ApiCategory.ml,
    sampleJson: '{"model":"M1","latency_ms":42,"output":0.88}',
  ),
  ApiContractRow(
    id: 'inference_stats',
    method: 'GET',
    path: '/api/v1/ml/inference-logs/stats/',
    usedBy: 'Day 61 · stats',
    status: ApiWireStatus.mock,
    category: ApiCategory.ml,
    sampleJson: '{"count":1204,"p95_ms":55}',
  ),
  ApiContractRow(
    id: 'incidents',
    method: 'GET',
    path: '/api/v1/incidents/',
    usedBy: 'Day 62 · incidents',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"results":[{"id":"i1","status":"open"}]}',
  ),
  ApiContractRow(
    id: 'alert_thresholds',
    method: 'GET',
    path: '/api/v1/alert-thresholds/',
    usedBy: 'Day 63 · thresholds',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"results":[{"metric":"dcs","value":0.75}]}',
  ),
  ApiContractRow(
    id: 'escalation_policies',
    method: 'GET',
    path: '/api/v1/escalation-policies/',
    usedBy: 'Day 64 · escalation',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"results":[{"name":"Tier2 after 60s"}]}',
  ),
  ApiContractRow(
    id: 'check_ins',
    method: 'POST',
    path: '/api/v1/check-ins/',
    usedBy: 'Day 65 · check-in timer',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"duration_min":30,"message":"Walking home"}',
  ),
  ApiContractRow(
    id: 'sos_templates',
    method: 'GET',
    path: '/api/v1/sos-templates/',
    usedBy: 'Day 66 · SOS templates',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"results":[{"body":"SOS {{location}} {{battery}}"}]}',
  ),
  ApiContractRow(
    id: 'notification_prefs',
    method: 'GET',
    path: '/api/v1/notification-prefs/',
    usedBy: 'Day 67 · notification prefs',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"categories":{"sos":true,"marketing":false}}',
  ),
  ApiContractRow(
    id: 'audit_log',
    method: 'GET',
    path: '/api/v1/audit-log/',
    usedBy: 'Day 68 · audit log',
    status: ApiWireStatus.mock,
    category: ApiCategory.privacy,
    sampleJson: '{"results":[{"action":"login","ts":"2026-06-01T10:00:00Z"}]}',
  ),
  ApiContractRow(
    id: 'audit_summary',
    method: 'GET',
    path: '/api/v1/audit-log/summary/',
    usedBy: 'Day 68 · audit stats',
    status: ApiWireStatus.mock,
    category: ApiCategory.privacy,
    sampleJson: '{"total":32,"sos_events":4}',
  ),
  ApiContractRow(
    id: 'data_export',
    method: 'POST',
    path: '/api/v1/data-export/',
    usedBy: 'Day 69 · data export',
    status: ApiWireStatus.mock,
    category: ApiCategory.privacy,
    sampleJson: '{"format":"zip","categories":["profile","sos"]}',
  ),
  ApiContractRow(
    id: 'privacy_settings',
    method: 'GET',
    path: '/api/v1/privacy/',
    usedBy: 'Day 70 · privacy settings',
    status: ApiWireStatus.mock,
    category: ApiCategory.privacy,
    sampleJson: '{"analytics":false,"crash_reports":true}',
  ),
  ApiContractRow(
    id: 'privacy_deletion',
    method: 'POST',
    path: '/api/v1/privacy/deletion-request/',
    usedBy: 'Day 169 · delete account',
    status: ApiWireStatus.missing,
    category: ApiCategory.privacy,
    sampleJson: '{"reason":"user_request","grace_days":30}',
  ),
  ApiContractRow(
    id: 'dashboard',
    method: 'GET',
    path: '/api/v1/dashboard/',
    usedBy: 'Day 81 · dashboard',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"mode":"MONITORING","protection_score":78}',
  ),
  ApiContractRow(
    id: 'onboarding_complete',
    method: 'POST',
    path: '/api/v1/onboarding/complete/',
    usedBy: 'Day 45 · onboarding step 5',
    status: ApiWireStatus.missing,
    category: ApiCategory.user,
    sampleJson: '{"protection_score":65,"skipped":["medical"]}',
  ),
  ApiContractRow(
    id: 'notifications_history',
    method: 'GET',
    path: '/api/v1/notifications/',
    usedBy: 'Day 88 · notification history',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"results":[{"title":"Drill complete","channel":"push"}]}',
  ),
  ApiContractRow(
    id: 'billing_invoices',
    method: 'GET',
    path: '/api/v1/billing/invoices/',
    usedBy: 'Day 95 · billing history',
    status: ApiWireStatus.mock,
    category: ApiCategory.billing,
    sampleJson: '{"results":[{"id":"inv_1","amount_inr":999,"status":"paid"}]}',
  ),
  ApiContractRow(
    id: 'payment_methods',
    method: 'GET',
    path: '/api/v1/billing/payment-methods/',
    usedBy: 'Day 94 · payment methods',
    status: ApiWireStatus.mock,
    category: ApiCategory.billing,
    sampleJson: '{"results":[{"brand":"visa","last4":"4242"}]}',
  ),
  ApiContractRow(
    id: 'subscription',
    method: 'GET',
    path: '/api/v1/billing/subscription/',
    usedBy: 'Day 92 · premium',
    status: ApiWireStatus.mock,
    category: ApiCategory.billing,
    sampleJson: '{"plan":"annual","renews_at":"2027-01-01"}',
  ),
  ApiContractRow(
    id: 'account_sessions',
    method: 'GET',
    path: '/api/v1/account/sessions/',
    usedBy: 'Day 179 · active sessions',
    status: ApiWireStatus.missing,
    category: ApiCategory.auth,
    sampleJson: '{"sessions":[{"device":"Pixel 7","last_active":"2026-06-01"}]}',
  ),
  ApiContractRow(
    id: 'account_delete',
    method: 'DELETE',
    path: '/api/v1/account/',
    usedBy: 'Day 169 · account deletion',
    status: ApiWireStatus.missing,
    category: ApiCategory.privacy,
    sampleJson: '{}',
  ),
  ApiContractRow(
    id: 'data_access_audit',
    method: 'GET',
    path: '/api/v1/data-access/audit-log/',
    usedBy: 'Day 173 · data access audit',
    status: ApiWireStatus.missing,
    category: ApiCategory.privacy,
    sampleJson: '{"results":[{"actor":"You","action":"export"}]}',
  ),
  ApiContractRow(
    id: 'retention_settings',
    method: 'GET',
    path: '/api/v1/retention-settings/',
    usedBy: 'Day 176 · retention',
    status: ApiWireStatus.missing,
    category: ApiCategory.privacy,
    sampleJson: '{"evidence_days":90,"location_days":30}',
  ),
  ApiContractRow(
    id: 'third_party_access',
    method: 'GET',
    path: '/api/v1/third-party-access/',
    usedBy: 'Day 175 · third-party log',
    status: ApiWireStatus.missing,
    category: ApiCategory.privacy,
    sampleJson: '{"grants":[{"app":"HealthKit","scope":"steps"}]}',
  ),
  ApiContractRow(
    id: 'chat_messages',
    method: 'GET',
    path: '/api/v1/chat/threads/',
    usedBy: 'Day 207 · live chat',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"threads":[{"id":"t1","unread":0}]}',
  ),
  ApiContractRow(
    id: 'chat_send',
    method: 'POST',
    path: '/api/v1/chat/messages/',
    usedBy: 'Day 207 · send message',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"thread_id":"t1","body":"I am safe now"}',
  ),
  ApiContractRow(
    id: 'user_preferences',
    method: 'PATCH',
    path: '/api/v1/users/preferences/',
    usedBy: 'Day 76 · DND settings',
    status: ApiWireStatus.mock,
    category: ApiCategory.user,
    sampleJson: '{"quiet_hours":{"start":22,"end":7}}',
  ),
  ApiContractRow(
    id: 'delivery_confirm',
    method: 'GET',
    path: '/api/v1/sos/delivery-status/',
    usedBy: 'Day 75 · delivery confirmation',
    status: ApiWireStatus.mock,
    category: ApiCategory.sos,
    sampleJson: '{"contacts":[{"name":"Amma","delivered":true}]}',
  ),
  ApiContractRow(
    id: 'consent_records',
    method: 'GET',
    path: '/api/v1/consent/',
    usedBy: 'Day 155 · consent mgmt',
    status: ApiWireStatus.mock,
    category: ApiCategory.privacy,
    sampleJson: '{"items":[{"key":"location","granted":true}]}',
  ),
  ApiContractRow(
    id: 'fcm_register',
    method: 'POST',
    path: '/api/v1/devices/fcm-token/',
    usedBy: 'Day 201 · device QA',
    status: ApiWireStatus.mock,
    category: ApiCategory.auth,
    sampleJson: '{"token":"fcm_...","platform":"android"}',
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d219TabProvider = StateProvider<int>((ref) => 0);
final _d219SearchProvider = StateProvider<String>((ref) => '');
final _d219CategoryProvider =
    StateProvider<ApiCategory>((ref) => ApiCategory.all);
final _d219SelectedProvider = StateProvider<String>((ref) => 'health');
final _d219StatusOverridesProvider =
    StateProvider<Map<String, ApiWireStatus>>((ref) => {});
final _d219HealthStateProvider =
    StateProvider<HealthPingState>((ref) => HealthPingState.idle);
final _d219HealthBodyProvider = StateProvider<String>((ref) => '');
final _d219HealthLatencyProvider = StateProvider<int?>((ref) => null);

const _kTabs = ['Matrix', 'JSON Sample', 'Export'];

ApiWireStatus _statusFor(ApiContractRow row, Map<String, ApiWireStatus> overrides) {
  return overrides[row.id] ?? row.status;
}

List<ApiContractRow> _filtered(
  String query,
  ApiCategory category,
  Map<String, ApiWireStatus> overrides,
) {
  return _kContracts.where((row) {
    final status = _statusFor(row, overrides);
    if (category == ApiCategory.missing && status != ApiWireStatus.missing) {
      return false;
    }
    if (category != ApiCategory.all &&
        category != ApiCategory.missing &&
        row.category != category) {
      return false;
    }
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return row.path.toLowerCase().contains(q) ||
        row.usedBy.toLowerCase().contains(q) ||
        row.method.toLowerCase().contains(q);
  }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day219BackendIntegrationAuditScreen extends ConsumerWidget {
  const Day219BackendIntegrationAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d219TabProvider);
    final overrides = ref.watch(_d219StatusOverridesProvider);
    final live = _kContracts
        .where((r) => _statusFor(r, overrides) == ApiWireStatus.live)
        .length;
    final missing = _kContracts
        .where((r) => _statusFor(r, overrides) == ApiWireStatus.missing)
        .length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 219 · Backend Audit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$live live · $missing miss',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
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
            onSelect: (i) => ref.read(_d219TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _MatrixTab(),
              1 => const _JsonSampleTab(),
              _ => const _ExportTab(),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _pingHealth(WidgetRef ref) async {
  ref.read(_d219HealthStateProvider.notifier).state = HealthPingState.loading;
  ref.read(_d219HealthBodyProvider.notifier).state = '';
  ref.read(_d219HealthLatencyProvider.notifier).state = null;

  final sw = Stopwatch()..start();
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.connectTimeout,
        headers: {'Accept': 'application/json'},
        validateStatus: (s) => s != null && s > 0,
      ),
    );
    final response = await dio.get<Map<String, dynamic>>('/api/v1/health/');
    sw.stop();
    ref.read(_d219HealthLatencyProvider.notifier).state = sw.elapsedMilliseconds;

    if (response.statusCode == 200) {
      ref.read(_d219HealthStateProvider.notifier).state = HealthPingState.ok;
      final body = response.data;
      ref.read(_d219HealthBodyProvider.notifier).state = body == null
          ? '{}'
          : const JsonEncoder.withIndent('  ').convert(body);
      ref.read(_d219StatusOverridesProvider.notifier).update(
            (m) => {...m, 'health': ApiWireStatus.live},
          );
    } else {
      ref.read(_d219HealthStateProvider.notifier).state = HealthPingState.error;
      ref.read(_d219HealthBodyProvider.notifier).state =
          'HTTP ${response.statusCode}';
    }
  } catch (e) {
    sw.stop();
    ref.read(_d219HealthStateProvider.notifier).state = HealthPingState.error;
    ref.read(_d219HealthLatencyProvider.notifier).state = sw.elapsedMilliseconds;
    ref.read(_d219HealthBodyProvider.notifier).state = e.toString();
  }
}

// ── Tab 0: Matrix ─────────────────────────────────────────────────────────────
class _MatrixTab extends ConsumerWidget {
  const _MatrixTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_d219SearchProvider);
    final category = ref.watch(_d219CategoryProvider);
    final overrides = ref.watch(_d219StatusOverridesProvider);
    final healthState = ref.watch(_d219HealthStateProvider);
    final healthLatency = ref.watch(_d219HealthLatencyProvider);
    final rows = _filtered(query, category, overrides);

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
          child: Text(
            '🟡 MOCK-NOW · Section A Day 19/20 · ${_kContracts.length} API contracts',
            style: const TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          onChanged: (v) => ref.read(_d219SearchProvider.notifier).state = v,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search path, screen, method…',
            hintStyle: const TextStyle(color: ZapColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: ZapColors.textMuted),
            filled: true,
            fillColor: ZapColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ApiCategory.values.map((c) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c.label),
                  selected: category == c,
                  onSelected: (_) =>
                      ref.read(_d219CategoryProvider.notifier).state = c,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart_rounded,
                      color: ZapColors.safe, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Live health ping',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'GET ${ApiConfig.baseUrl}/api/v1/health/',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Semantics(
                label: 'Ping health endpoint',
                button: true,
                child: FilledButton.icon(
                  onPressed: healthState == HealthPingState.loading
                      ? null
                      : () => _pingHealth(ref),
                  icon: healthState == HealthPingState.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 18),
                  label: Text(
                    healthState == HealthPingState.loading
                        ? 'Pinging…'
                        : 'Ping /api/v1/health/',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 75),
                    backgroundColor: ZapColors.safe,
                  ),
                ),
              ),
              if (healthState != HealthPingState.idle) ...[
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  switch (healthState) {
                    HealthPingState.ok =>
                      '200 OK${healthLatency != null ? " · ${healthLatency}ms" : ""}',
                    HealthPingState.error =>
                      'Unreachable${healthLatency != null ? " · ${healthLatency}ms" : ""} — backend offline?',
                    _ => '',
                  },
                  style: TextStyle(
                    color: healthState == HealthPingState.ok
                        ? ZapColors.safe
                        : ZapColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          '${rows.length} endpoints',
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...rows.map((row) {
          final status = _statusFor(row, overrides);
          return _ContractRowTile(
            row: row,
            status: status,
            onTap: () {
              ref.read(_d219SelectedProvider.notifier).state = row.id;
              ref.read(_d219TabProvider.notifier).state = 1;
            },
          );
        }),
      ],
    );
  }
}

class _ContractRowTile extends StatelessWidget {
  final ApiContractRow row;
  final ApiWireStatus status;
  final VoidCallback onTap;

  const _ContractRowTile({
    required this.row,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${row.method} ${row.path}. ${status.label}. ${row.usedBy}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: status == ApiWireStatus.missing
                  ? ZapColors.danger.withOpacity(0.4)
                  : ZapColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _methodColor(row.method).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  row.method,
                  style: TextStyle(
                    color: _methodColor(row.method),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.path,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      row.usedBy,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: status),
              const Icon(Icons.chevron_right_rounded,
                  color: ZapColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

Color _methodColor(String method) => switch (method) {
      'GET' => ZapColors.info,
      'POST' => ZapColors.safe,
      'PATCH' => ZapColors.warning,
      'DELETE' => ZapColors.danger,
      _ => ZapColors.textSecondary,
    };

class _StatusChip extends StatelessWidget {
  final ApiWireStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Tab 1: JSON sample ────────────────────────────────────────────────────────
class _JsonSampleTab extends ConsumerWidget {
  const _JsonSampleTab();

  ApiContractRow? _find(String id) {
    for (final r in _kContracts) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(_d219SelectedProvider);
    final overrides = ref.watch(_d219StatusOverridesProvider);
    final healthBody = ref.watch(_d219HealthBodyProvider);
    final row = _find(selectedId) ?? _kContracts.first;
    final status = _statusFor(row, overrides);
    final prettyJson = _prettyJson(row.sampleJson);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _kContracts.take(12).map((r) {
            final sel = r.id == selectedId;
            return ActionChip(
              label: Text(r.method, style: const TextStyle(fontSize: 10)),
              onPressed: () =>
                  ref.read(_d219SelectedProvider.notifier).state = r.id,
              backgroundColor:
                  sel ? ZapColors.info.withOpacity(0.2) : ZapColors.bgElevated,
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.md),
        DropdownButtonFormField<String>(
          value: selectedId,
          decoration: InputDecoration(
            filled: true,
            fillColor: ZapColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
          ),
          dropdownColor: ZapColors.bgCard,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
          items: _kContracts
              .map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Text(
                    '${r.method} ${r.path}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) ref.read(_d219SelectedProvider.notifier).state = v;
          },
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            _StatusChip(status: status),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.usedBy,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Expected JSON sample',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            prettyJson,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
        if (row.id == 'health' && healthBody.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Live ping response',
            style: TextStyle(
              color: ZapColors.safe,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
            ),
            child: SelectableText(
              healthBody,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy JSON sample',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON sample copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy JSON sample'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

String _prettyJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}

// ── Tab 2: Export ─────────────────────────────────────────────────────────────
class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  String _buildCsv(Map<String, ApiWireStatus> overrides) {
    final buf = StringBuffer()
      ..writeln('method,path,status,screen,category');
    for (final row in _kContracts) {
      final status = _statusFor(row, overrides);
      buf.writeln(
        '${row.method},"${row.path}",${status.label},"${row.usedBy}",${row.category.label}',
      );
    }
    return buf.toString();
  }

  String _buildSummary(Map<String, ApiWireStatus> overrides) {
    final live = _kContracts
        .where((r) => _statusFor(r, overrides) == ApiWireStatus.live)
        .length;
    final mock = _kContracts
        .where((r) => _statusFor(r, overrides) == ApiWireStatus.mock)
        .length;
    final missing = _kContracts
        .where((r) => _statusFor(r, overrides) == ApiWireStatus.missing)
        .length;
    final buf = StringBuffer()
      ..writeln('ZapSafe Backend Integration Audit — Day 219')
      ..writeln('Total: ${_kContracts.length} contracts')
      ..writeln('Live: $live · Mock: $mock · Missing: $missing')
      ..writeln('')
      ..writeln('Missing endpoints:');
    for (final row in _kContracts) {
      if (_statusFor(row, overrides) == ApiWireStatus.missing) {
        buf.writeln('  ${row.method} ${row.path} — ${row.usedBy}');
      }
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(_d219StatusOverridesProvider);
    final summary = _buildSummary(overrides);
    final csv = _buildCsv(overrides);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Integration summary',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
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
          child: Text(
            summary,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy audit summary',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Summary copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy summary'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.warning,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy CSV matrix',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied')),
              );
            },
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            label: const Text('Copy CSV'),
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
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 221 — Police Dashboard (Section B catch-up).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
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
                        color: selected ? ZapColors.warning : Colors.transparent,
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
                      fontSize: 12,
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
