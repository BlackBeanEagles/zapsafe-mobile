/// Day 229 — Feature Regression Runner (44 Features)
///
/// Section B (Days 221-240): manual QA checklist for all 44 product features
/// plus 9 visible LP defenses (53 rows). Progress ring, route deep-links,
/// and clipboard export report.
///
/// Tag: 🟢 FRONTEND-ONLY — QA harness; no backend calls.
///
/// Route: [AppRoutes.featureRegressionRunner] → `/feature-regression-runner`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
enum RegressionVerdict { pending, pass, fail }

extension RegressionVerdictX on RegressionVerdict {
  String get label => switch (this) {
        RegressionVerdict.pending => 'Pending',
        RegressionVerdict.pass => 'Pass',
        RegressionVerdict.fail => 'Fail',
      };

  Color get color => switch (this) {
        RegressionVerdict.pending => ZapColors.textMuted,
        RegressionVerdict.pass => ZapColors.safe,
        RegressionVerdict.fail => ZapColors.danger,
      };

  IconData get icon => switch (this) {
        RegressionVerdict.pending => Icons.radio_button_unchecked_rounded,
        RegressionVerdict.pass => Icons.check_circle_rounded,
        RegressionVerdict.fail => Icons.cancel_rounded,
      };
}

enum RegressionCategory {
  authCore,
  sosPipeline,
  detectionMl,
  contactsAlerts,
  evidenceHistory,
  dashboardScore,
  settingsPremium,
  lpDefense,
}

extension RegressionCategoryX on RegressionCategory {
  String get label => switch (this) {
        RegressionCategory.authCore => 'Auth & Core',
        RegressionCategory.sosPipeline => 'SOS Pipeline',
        RegressionCategory.detectionMl => 'Detection & ML',
        RegressionCategory.contactsAlerts => 'Contacts & Alerts',
        RegressionCategory.evidenceHistory => 'Evidence & History',
        RegressionCategory.dashboardScore => 'Dashboard & Score',
        RegressionCategory.settingsPremium => 'Settings & Premium',
        RegressionCategory.lpDefense => 'LP Defenses (visible)',
      };

  Color get color => switch (this) {
        RegressionCategory.authCore => const Color(0xFF3B82F6),
        RegressionCategory.sosPipeline => const Color(0xFFEF4444),
        RegressionCategory.detectionMl => const Color(0xFF8B5CF6),
        RegressionCategory.contactsAlerts => const Color(0xFFF59E0B),
        RegressionCategory.evidenceHistory => const Color(0xFF10B981),
        RegressionCategory.dashboardScore => const Color(0xFF06B6D4),
        RegressionCategory.settingsPremium => const Color(0xFFEC4899),
        RegressionCategory.lpDefense => const Color(0xFFF97316),
      };
}

class RegressionRow {
  final String id;
  final String name;
  final String dayRef;
  final RegressionCategory category;
  final String? route;
  final bool isLp;

  const RegressionRow({
    required this.id,
    required this.name,
    required this.dayRef,
    required this.category,
    this.route,
    this.isLp = false,
  });
}

/// 44 features + 9 visible LP defenses = 53 rows (MASTER_HANDOFF categories).
const _kRows = [
  // Auth & Core (5)
  RegressionRow(
    id: 'f01',
    name: 'Phone + OTP authentication',
    dayRef: 'Day 6-8',
    category: RegressionCategory.authCore,
    route: AppRoutes.phoneEntry,
  ),
  RegressionRow(
    id: 'f02',
    name: '5-step onboarding flow',
    dayRef: 'Day 41-45',
    category: RegressionCategory.authCore,
    route: AppRoutes.onboardingStep1,
  ),
  RegressionRow(
    id: 'f03',
    name: 'Permission onboarding flow',
    dayRef: 'Day 12',
    category: RegressionCategory.authCore,
    route: AppRoutes.onboardingPermissions,
  ),
  RegressionRow(
    id: 'f04',
    name: 'Device tier detection',
    dayRef: 'Day 13',
    category: RegressionCategory.authCore,
    route: AppRoutes.deviceTier,
  ),
  RegressionRow(
    id: 'f05',
    name: 'Tier-gated feature flags',
    dayRef: 'Day 14',
    category: RegressionCategory.authCore,
    route: AppRoutes.featureFlags,
  ),
  // SOS Pipeline (8)
  RegressionRow(
    id: 'f06',
    name: 'Alert Pending countdown',
    dayRef: 'Day 71',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.alertPending,
  ),
  RegressionRow(
    id: 'f07',
    name: 'SOS Active screen',
    dayRef: 'Day 76',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.sosActive,
  ),
  RegressionRow(
    id: 'f08',
    name: 'Manual SOS trigger wiring',
    dayRef: 'Day 39',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.day39StateWiring,
  ),
  RegressionRow(
    id: 'f09',
    name: 'DCS stream + auto-trigger',
    dayRef: 'Day 33',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.dcsStream,
  ),
  RegressionRow(
    id: 'f10',
    name: 'IMU fall detection',
    dayRef: 'Day 36',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.imuService,
  ),
  RegressionRow(
    id: 'f11',
    name: 'GPS adaptive polling',
    dayRef: 'Day 37',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.gpsService,
  ),
  RegressionRow(
    id: 'f12',
    name: '7-state app machine',
    dayRef: 'Day 38',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.day38FallbackAndState,
  ),
  RegressionRow(
    id: 'f13',
    name: 'Trigger orchestrator',
    dayRef: 'Day 39',
    category: RegressionCategory.sosPipeline,
    route: AppRoutes.day39StateWiring,
  ),
  // Detection & ML (7)
  RegressionRow(
    id: 'f14',
    name: 'Background foreground service',
    dayRef: 'Day 21',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.backgroundEngine,
  ),
  RegressionRow(
    id: 'f15',
    name: 'LP4 watchdog (WorkManager)',
    dayRef: 'Day 24',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.lp4Watchdog,
  ),
  RegressionRow(
    id: 'f16',
    name: 'Audio capture pipeline',
    dayRef: 'Day 26',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.audioCapture,
  ),
  RegressionRow(
    id: 'f17',
    name: 'MFCC feature extraction',
    dayRef: 'Day 27',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.audioFeatures,
  ),
  RegressionRow(
    id: 'f18',
    name: 'DCS inference engine (4 slots)',
    dayRef: 'Day 32',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.dcsEngine,
  ),
  RegressionRow(
    id: 'f19',
    name: 'TFLite model registry',
    dayRef: 'Day 31',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.tfliteModels,
  ),
  RegressionRow(
    id: 'f20',
    name: 'Isolate inference latency',
    dayRef: 'Day 34',
    category: RegressionCategory.detectionMl,
    route: AppRoutes.isolateLatency,
  ),
  // Contacts & Alerts (7)
  RegressionRow(
    id: 'f21',
    name: 'Contact management v2',
    dayRef: 'Day 83',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.contactsV2,
  ),
  RegressionRow(
    id: 'f22',
    name: 'Escalation policies v2',
    dayRef: 'Day 86',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.escalationPoliciesV2,
  ),
  RegressionRow(
    id: 'f23',
    name: 'SOS message templates v2',
    dayRef: 'Day 87',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.sosTemplatesV2,
  ),
  RegressionRow(
    id: 'f24',
    name: 'Alert thresholds v2',
    dayRef: 'Day 85',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.alertThresholdsV2,
  ),
  RegressionRow(
    id: 'f25',
    name: 'Notification preferences',
    dayRef: 'Day 67',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.notificationPrefs,
  ),
  RegressionRow(
    id: 'f26',
    name: 'Delivery confirmation',
    dayRef: 'Day 75',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.deliveryConfirmation,
  ),
  RegressionRow(
    id: 'f27',
    name: 'Do Not Disturb override',
    dayRef: 'Day 73',
    category: RegressionCategory.contactsAlerts,
    route: AppRoutes.doNotDisturb,
  ),
  // Evidence & History (6)
  RegressionRow(
    id: 'f28',
    name: 'Evidence vault',
    dayRef: 'Day 82',
    category: RegressionCategory.evidenceHistory,
    route: AppRoutes.evidenceVault,
  ),
  RegressionRow(
    id: 'f29',
    name: 'Notification history v2',
    dayRef: 'Day 88',
    category: RegressionCategory.evidenceHistory,
    route: AppRoutes.notificationHistoryV2,
  ),
  RegressionRow(
    id: 'f30',
    name: 'Activity audit log v2',
    dayRef: 'Day 89',
    category: RegressionCategory.evidenceHistory,
    route: AppRoutes.activityAuditLogV2,
  ),
  RegressionRow(
    id: 'f31',
    name: 'SOS history timeline',
    dayRef: 'Day 228',
    category: RegressionCategory.evidenceHistory,
    route: AppRoutes.sosHistoryTimeline,
  ),
  RegressionRow(
    id: 'f32',
    name: 'Check-in timers',
    dayRef: 'Day 65',
    category: RegressionCategory.evidenceHistory,
    route: AppRoutes.checkIns,
  ),
  RegressionRow(
    id: 'f33',
    name: 'Emergency drills',
    dayRef: 'Day 84',
    category: RegressionCategory.evidenceHistory,
    route: AppRoutes.emergencyDrills,
  ),
  // Dashboard & Score (5)
  RegressionRow(
    id: 'f34',
    name: 'Alert dashboard v2',
    dayRef: 'Day 80',
    category: RegressionCategory.dashboardScore,
    route: AppRoutes.alertDashboardV2,
  ),
  RegressionRow(
    id: 'f35',
    name: 'Protection score ring',
    dayRef: 'Day 59',
    category: RegressionCategory.dashboardScore,
    route: AppRoutes.protectionScore,
  ),
  RegressionRow(
    id: 'f36',
    name: 'Safe zones',
    dayRef: 'Day 58',
    category: RegressionCategory.dashboardScore,
    route: AppRoutes.safeZones,
  ),
  RegressionRow(
    id: 'f37',
    name: 'Drill mode',
    dayRef: 'Day 60',
    category: RegressionCategory.dashboardScore,
    route: AppRoutes.drillMode,
  ),
  RegressionRow(
    id: 'f38',
    name: 'ML analytics dashboard',
    dayRef: 'Day 57',
    category: RegressionCategory.dashboardScore,
    route: AppRoutes.mlAnalytics,
  ),
  // Settings & Premium (6)
  RegressionRow(
    id: 'f39',
    name: 'Settings hub v2',
    dayRef: 'Day 81',
    category: RegressionCategory.settingsPremium,
    route: AppRoutes.settingsV2,
  ),
  RegressionRow(
    id: 'f40',
    name: 'Premium subscription',
    dayRef: 'Day 91',
    category: RegressionCategory.settingsPremium,
    route: AppRoutes.premiumSubscription,
  ),
  RegressionRow(
    id: 'f41',
    name: 'Payment methods',
    dayRef: 'Day 94',
    category: RegressionCategory.settingsPremium,
    route: AppRoutes.paymentMethods,
  ),
  RegressionRow(
    id: 'f42',
    name: 'Language settings (15 langs)',
    dayRef: 'Day 96',
    category: RegressionCategory.settingsPremium,
    route: AppRoutes.languageSettings,
  ),
  RegressionRow(
    id: 'f43',
    name: 'Accessibility settings',
    dayRef: 'Day 97',
    category: RegressionCategory.settingsPremium,
    route: AppRoutes.accessibilitySettings,
  ),
  RegressionRow(
    id: 'f44',
    name: 'Help & support',
    dayRef: 'Day 99',
    category: RegressionCategory.settingsPremium,
    route: AppRoutes.helpSupport,
  ),
  // LP Defenses — 9 visible (9)
  RegressionRow(
    id: 'lp03',
    name: 'LP3 · Duress PIN silent escalation',
    dayRef: 'Day 39',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.day39StateWiring,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp04',
    name: 'LP4 · Service watchdog auto-restart',
    dayRef: 'Day 24',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.lp4Watchdog,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp12',
    name: 'LP12 · GPS accuracy gate (≤50 m)',
    dayRef: 'Day 37',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.gpsService,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp15',
    name: 'LP15 · Battery threshold handler',
    dayRef: 'Day 38',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.day38FallbackAndState,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp16',
    name: 'LP16 · Vault PIN (separate from SOS)',
    dayRef: 'Day 82',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.evidenceVault,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp18',
    name: 'LP18 · Biometric gate (6 operations)',
    dayRef: 'Day 183',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.biometricLock,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp23',
    name: 'LP23 · Vault cascade (rotate / wipe)',
    dayRef: 'Day 82',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.evidenceVault,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp24',
    name: 'LP24 · Trusted location auto-learn',
    dayRef: 'Day 43',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.onboardingStep3,
    isLp: true,
  ),
  RegressionRow(
    id: 'lp27',
    name: 'LP27 · Blank-screen panic UI',
    dayRef: 'Day 71',
    category: RegressionCategory.lpDefense,
    route: AppRoutes.alertPending,
    isLp: true,
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d229TabProvider = StateProvider<int>((ref) => 0);
final _d229VerdictsProvider =
    StateProvider<Map<String, RegressionVerdict>>((ref) => {});
final _d229FilterProvider = StateProvider<RegressionCategory?>((ref) => null);

const _kTabs = ['Checklist', 'Progress', 'Export'];

const _kTotalRows = 53;
const _kFeatureCount = 44;
const _kLpCount = 9;

({int pass, int fail, int pending, int evaluated}) _stats(
  Map<String, RegressionVerdict> verdicts,
) {
  var pass = 0;
  var fail = 0;
  for (final row in _kRows) {
    final v = verdicts[row.id] ?? RegressionVerdict.pending;
    if (v == RegressionVerdict.pass) pass++;
    if (v == RegressionVerdict.fail) fail++;
  }
  final evaluated = pass + fail;
  final pending = _kRows.length - evaluated;
  return (pass: pass, fail: fail, pending: pending, evaluated: evaluated);
}

String _buildReport(Map<String, RegressionVerdict> verdicts) {
  final s = _stats(verdicts);
  final buf = StringBuffer()
    ..writeln('ZapSafe Feature Regression Report — Day 229')
    ..writeln(
        'Total: $_kTotalRows ($_kFeatureCount features + $_kLpCount LP defenses)')
    ..writeln('Pass: ${s.pass} · Fail: ${s.fail} · Pending: ${s.pending}')
    ..writeln('Evaluated: ${s.evaluated}/${_kRows.length}')
    ..writeln();

  RegressionCategory? lastCat;
  for (final row in _kRows) {
    if (row.category != lastCat) {
      lastCat = row.category;
      buf.writeln('[${row.category.label}]');
    }
    final v = verdicts[row.id] ?? RegressionVerdict.pending;
    final mark = switch (v) {
      RegressionVerdict.pass => 'PASS',
      RegressionVerdict.fail => 'FAIL',
      RegressionVerdict.pending => 'PENDING',
    };
    final route = row.route ?? 'no route';
    buf.writeln('  $mark · ${row.id} · ${row.name} (${row.dayRef}) → $route');
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day229FeatureRegressionRunnerScreen extends ConsumerWidget {
  const Day229FeatureRegressionRunnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d229TabProvider);
    final verdicts = ref.watch(_d229VerdictsProvider);
    final stats = _stats(verdicts);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 229 · Regression Runner'),
        actions: [
          TextButton(
            onPressed: verdicts.isEmpty
                ? null
                : () => ref.read(_d229VerdictsProvider.notifier).state = {},
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProgressRingHeader(stats: stats),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d229TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _ChecklistTab(verdicts: verdicts),
              1 => _ProgressTab(verdicts: verdicts, stats: stats),
              _ => _ExportTab(verdicts: verdicts, stats: stats),
            },
          ),
        ],
      ),
    );
  }
}

void _setVerdict(WidgetRef ref, String id, RegressionVerdict verdict) {
  ref.read(_d229VerdictsProvider.notifier).update((m) => {...m, id: verdict});
}

// ── Header ────────────────────────────────────────────────────────────────────
class _ProgressRingHeader extends StatelessWidget {
  final ({int pass, int fail, int pending, int evaluated}) stats;

  const _ProgressRingHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final passRate = stats.evaluated == 0 ? 0.0 : stats.pass / stats.evaluated;
    final coverage = stats.evaluated / _kRows.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      color: ZapColors.bgCard,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: coverage,
                  strokeWidth: 6,
                  backgroundColor: ZapColors.border,
                  color: ZapColors.info.withOpacity(0.5),
                ),
                CircularProgressIndicator(
                  value: stats.evaluated == 0 ? 0 : passRate,
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  color: stats.fail > 0 ? ZapColors.warning : ZapColors.safe,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stats.pass}',
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      '/ $_kTotalRows',
                      style: TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🟢 FRONTEND-ONLY · Section B Day 9/20',
                  style: TextStyle(color: ZapColors.safe, fontSize: 10),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '$_kFeatureCount features + $_kLpCount LP defenses · ${stats.evaluated} evaluated',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _StatChip(
                      label: 'Pass',
                      value: '${stats.pass}',
                      color: ZapColors.safe,
                    ),
                    _StatChip(
                      label: 'Fail',
                      value: '${stats.fail}',
                      color: ZapColors.danger,
                    ),
                    _StatChip(
                      label: 'Pending',
                      value: '${stats.pending}',
                      color: ZapColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  final Map<String, RegressionVerdict> verdicts;

  const _ChecklistTab({required this.verdicts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d229FilterProvider);
    final rows = filter == null
        ? _kRows
        : _kRows.where((r) => r.category == filter).toList();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('All ($_kTotalRows)'),
              selected: filter == null,
              onSelected: (_) =>
                  ref.read(_d229FilterProvider.notifier).state = null,
              selectedColor: ZapColors.info.withOpacity(0.2),
              checkmarkColor: ZapColors.info,
            ),
            for (final cat in RegressionCategory.values)
              FilterChip(
                label: Text(
                  cat.label.split(' ').first,
                  style: const TextStyle(fontSize: 10),
                ),
                selected: filter == cat,
                onSelected: (_) =>
                    ref.read(_d229FilterProvider.notifier).state = cat,
                selectedColor: cat.color.withOpacity(0.2),
                checkmarkColor: cat.color,
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  final next = <String, RegressionVerdict>{...verdicts};
                  for (final row in rows) {
                    next[row.id] = RegressionVerdict.pass;
                  }
                  ref.read(_d229VerdictsProvider.notifier).state = next;
                },
                child: const Text('Mark visible pass'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push(AppRoutes.qaPass),
                child: const Text('Day 198 QA flows'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._buildGroupedRows(context, ref, rows, verdicts),
      ],
    );
  }

  List<Widget> _buildGroupedRows(
    BuildContext context,
    WidgetRef ref,
    List<RegressionRow> rows,
    Map<String, RegressionVerdict> verdicts,
  ) {
    final widgets = <Widget>[];
    RegressionCategory? last;

    for (final row in rows) {
      if (row.category != last) {
        last = row.category;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: ZapSpacing.sm, bottom: 6),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: row.category.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                row.category.label,
                style: TextStyle(
                  color: row.category.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ));
      }
      widgets.add(_RegressionRowCard(
        row: row,
        verdict: verdicts[row.id] ?? RegressionVerdict.pending,
        onPass: () => _setVerdict(ref, row.id, RegressionVerdict.pass),
        onFail: () => _setVerdict(ref, row.id, RegressionVerdict.fail),
        onClear: () {
          ref.read(_d229VerdictsProvider.notifier).update((m) {
            final next = {...m}..remove(row.id);
            return next;
          });
        },
        onOpenRoute: row.route == null ? null : () => context.push(row.route!),
      ));
    }
    return widgets;
  }
}

class _RegressionRowCard extends StatelessWidget {
  final RegressionRow row;
  final RegressionVerdict verdict;
  final VoidCallback onPass;
  final VoidCallback onFail;
  final VoidCallback onClear;
  final VoidCallback? onOpenRoute;

  const _RegressionRowCard({
    required this.row,
    required this.verdict,
    required this.onPass,
    required this.onFail,
    required this.onClear,
    this.onOpenRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: verdict == RegressionVerdict.fail
              ? ZapColors.danger.withOpacity(0.4)
              : verdict == RegressionVerdict.pass
                  ? ZapColors.safe.withOpacity(0.35)
                  : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(verdict.icon, color: verdict.color, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${row.id.toUpperCase()} · ${row.dayRef}'
                      '${row.isLp ? ' · LP' : ''}',
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenRoute != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  color: ZapColors.info,
                  tooltip: 'Open screen',
                  onPressed: onOpenRoute,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              _VerdictButton(
                label: 'Pass',
                selected: verdict == RegressionVerdict.pass,
                color: ZapColors.safe,
                onTap: onPass,
              ),
              const SizedBox(width: 6),
              _VerdictButton(
                label: 'Fail',
                selected: verdict == RegressionVerdict.fail,
                color: ZapColors.danger,
                onTap: onFail,
              ),
              const Spacer(),
              if (verdict != RegressionVerdict.pending)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear', style: TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _VerdictButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(0.18) : ZapColors.bgElevated,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? color : ZapColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : ZapColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Progress ───────────────────────────────────────────────────────────
class _ProgressTab extends StatelessWidget {
  final Map<String, RegressionVerdict> verdicts;
  final ({int pass, int fail, int pending, int evaluated}) stats;

  const _ProgressTab({required this.verdicts, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (stats.evaluated == _kRows.length && stats.fail == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            margin: const EdgeInsets.only(bottom: ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.12),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: ZapColors.safe),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'All 53 rows pass — regression green ✅',
                    style: TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...RegressionCategory.values.map((cat) {
          final catRows = _kRows.where((r) => r.category == cat).toList();
          final catPass = catRows
              .where(
                (r) =>
                    (verdicts[r.id] ?? RegressionVerdict.pending) ==
                    RegressionVerdict.pass,
              )
              .length;
          final catFail = catRows
              .where(
                (r) =>
                    (verdicts[r.id] ?? RegressionVerdict.pending) ==
                    RegressionVerdict.fail,
              )
              .length;
          final pct = catRows.isEmpty ? 0.0 : catPass / catRows.length;

          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
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
                    Expanded(
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          color: cat.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '$catPass/${catRows.length}',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: ZapColors.border,
                    color: catFail > 0 ? ZapColors.warning : cat.color,
                  ),
                ),
                if (catFail > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$catFail failing',
                      style: const TextStyle(
                        color: ZapColors.danger,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        ActionChip(
          avatar: const Icon(Icons.history_rounded, size: 16),
          label: const Text('Open Day 228 SOS history'),
          onPressed: () => context.push(AppRoutes.sosHistoryTimeline),
        ),
      ],
    );
  }
}

// ── Tab 2: Export ─────────────────────────────────────────────────────────────
class _ExportTab extends StatelessWidget {
  final Map<String, RegressionVerdict> verdicts;
  final ({int pass, int fail, int pending, int evaluated}) stats;

  const _ExportTab({required this.verdicts, required this.stats});

  @override
  Widget build(BuildContext context) {
    final report = _buildReport(verdicts);
    final preview = report.split('\n').take(16).join('\n');

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Export regression report',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          '${stats.pass} pass · ${stats.fail} fail · ${stats.pending} pending',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            preview,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        if (report.split('\n').length > 16)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '… ${report.split('\n').length - 16} more lines in full report',
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: stats.evaluated == 0
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: report));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied report (${stats.evaluated} evaluated rows)',
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy full report'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.info,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.deviceQaHarness),
          icon: const Icon(Icons.devices_rounded, size: 18),
          label: const Text('Day 201 device QA harness'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
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
            'Tomorrow: Day 233 — Decoy weather app mode.',
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
