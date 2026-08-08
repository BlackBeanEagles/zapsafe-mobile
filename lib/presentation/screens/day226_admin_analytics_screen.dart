/// Day 226 — Admin Analytics (Internal)
///
/// Section B (Days 221-240): staff-only mock analytics dashboard — DAU, SOS 24h,
/// false-positive rate, crash-free %. Gated behind dev flag / About long-press sim.
///
/// Tag: 🟡 MOCK-NOW — GET /api/v1/admin/analytics/summary/ (staff JWT).
///
/// Route: [AppRoutes.adminAnalytics] → `/admin-analytics`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Mock analytics ────────────────────────────────────────────────────────────
class AdminAnalyticsSummary {
  final int dau;
  final int sos24h;
  final double fpRate;
  final double crashFreePct;
  final int referralsToday;
  final int policeConnections;

  const AdminAnalyticsSummary({
    required this.dau,
    required this.sos24h,
    required this.fpRate,
    required this.crashFreePct,
    required this.referralsToday,
    required this.policeConnections,
  });

  Map<String, dynamic> toJson() => {
        'dau': dau,
        'sos_24h': sos24h,
        'fp_rate': fpRate,
        'crash_free_pct': crashFreePct,
        'referrals_today': referralsToday,
        'police_connections_active': policeConnections,
      };
}

const _kSummary = AdminAnalyticsSummary(
  dau: 847,
  sos24h: 12,
  fpRate: 0.048,
  crashFreePct: 99.91,
  referralsToday: 14,
  policeConnections: 3,
);

const _kApiSample = '''{
  "dau": 847,
  "sos_24h": 12,
  "fp_rate": 0.048,
  "crash_free_pct": 99.91,
  "referrals_today": 14,
  "police_connections_active": 3
}''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d226TabProvider = StateProvider<int>((ref) => 0);
final _d226UnlockedProvider = StateProvider<bool>((ref) => false);
final _d226DevFlagProvider = StateProvider<bool>((ref) => false);
final _d226RefreshingProvider = StateProvider<bool>((ref) => false);
final _d226LastRefreshProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Dashboard', 'Access Gate', 'API Contract'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day226AdminAnalyticsScreen extends ConsumerWidget {
  const Day226AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d226TabProvider);
    final unlocked = ref.watch(_d226UnlockedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 226 · Admin Analytics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: unlocked
                      ? ZapColors.danger.withOpacity(0.15)
                      : ZapColors.textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: unlocked
                        ? ZapColors.danger.withOpacity(0.45)
                        : ZapColors.border,
                  ),
                ),
                child: Text(
                  unlocked ? 'STAFF' : 'LOCKED',
                  style: TextStyle(
                    color: unlocked ? ZapColors.danger : ZapColors.textMuted,
                    fontSize: 10,
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
            onSelect: (i) => ref.read(_d226TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _DashboardTab(),
              1 => const _AccessGateTab(),
              _ => const _ApiContractTab(),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _mockRefresh(WidgetRef ref) async {
  ref.read(_d226RefreshingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 900));
  ref.read(_d226RefreshingProvider.notifier).state = false;
  final now = DateTime.now();
  ref.read(_d226LastRefreshProvider.notifier).state =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

void _unlock(WidgetRef ref) {
  ref.read(_d226UnlockedProvider.notifier).state = true;
}

void _lock(WidgetRef ref) {
  ref.read(_d226UnlockedProvider.notifier).state = false;
  ref.read(_d226DevFlagProvider.notifier).state = false;
}

// ── Tab 0: Dashboard ──────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(_d226UnlockedProvider);
    final refreshing = ref.watch(_d226RefreshingProvider);
    final lastRefresh = ref.watch(_d226LastRefreshProvider);

    if (!unlocked) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          const _StaffBanner(),
          const SizedBox(height: ZapSpacing.xl),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.xl),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.lock_rounded,
                    color: ZapColors.textMuted.withOpacity(0.6), size: 48),
                const SizedBox(height: ZapSpacing.md),
                const Text(
                  'Internal dashboard locked',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const Text(
                  'Unlock via Access Gate tab — simulate long-press on '
                  'Settings → About version, or enable dev flag.',
                  style: TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ZapSpacing.lg),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(_d226TabProvider.notifier).state = 1,
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text('Go to Access Gate'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ZapColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _StaffBanner(),
        const SizedBox(height: ZapSpacing.md),
        if (lastRefresh != null)
          Text(
            'Last refresh $lastRefresh IST',
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
        const SizedBox(height: ZapSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ZapSpacing.sm,
          crossAxisSpacing: ZapSpacing.sm,
          childAspectRatio: 1.25,
          children: [
            _MetricCard(
              label: 'DAU',
              value: '${_kSummary.dau}',
              subtitle: 'Daily active users',
              color: ZapColors.info,
              icon: Icons.people_rounded,
            ),
            _MetricCard(
              label: 'SOS (24h)',
              value: '${_kSummary.sos24h}',
              subtitle: 'Alerts last 24 hours',
              color: ZapColors.danger,
              icon: Icons.sos_rounded,
            ),
            _MetricCard(
              label: 'FP rate',
              value: '${(_kSummary.fpRate * 100).toStringAsFixed(1)}%',
              subtitle: 'False positive rate',
              color: ZapColors.warning,
              icon: Icons.warning_amber_rounded,
            ),
            _MetricCard(
              label: 'Crash-free',
              value: '${_kSummary.crashFreePct}%',
              subtitle: 'Sessions crash-free',
              color: ZapColors.safe,
              icon: Icons.verified_rounded,
            ),
            _MetricCard(
              label: 'Referrals today',
              value: '${_kSummary.referralsToday}',
              subtitle: 'Day 224 funnel',
              color: ZapColors.safe,
              icon: Icons.card_giftcard_rounded,
            ),
            _MetricCard(
              label: 'Police links',
              value: '${_kSummary.policeConnections}',
              subtitle: 'Active integrations',
              color: ZapColors.info,
              icon: Icons.local_police_rounded,
            ),
          ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Health snapshot',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              _HealthRow(
                label: 'FP rate target',
                value: '≤ 5.0%',
                pass: _kSummary.fpRate <= 0.05,
                actual: '${(_kSummary.fpRate * 100).toStringAsFixed(1)}%',
              ),
              _HealthRow(
                label: 'Crash-free target',
                value: '≥ 99.5%',
                pass: _kSummary.crashFreePct >= 99.5,
                actual: '${_kSummary.crashFreePct}%',
              ),
              _HealthRow(
                label: 'SOS volume',
                value: 'Normal band',
                pass: _kSummary.sos24h < 50,
                actual: '${_kSummary.sos24h} / 24h',
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: refreshing ? null : () => _mockRefresh(ref),
          icon: refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(refreshing ? 'Refreshing…' : 'Refresh summary'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.info,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _lock(ref),
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: const Text('Lock dashboard'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            foregroundColor: ZapColors.danger,
            side: const BorderSide(color: ZapColors.danger),
          ),
        ),
      ],
    );
  }
}

class _StaffBanner extends StatelessWidget {
  const _StaffBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.danger.withOpacity(0.45)),
      ),
      child: const Text(
        '🟡 MOCK-NOW · Section B Day 6/20 · STAFF ONLY · INTERNAL',
        style: TextStyle(
          color: ZapColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final String actual;
  final bool pass;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.actual,
    required this.pass,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
          const SizedBox(width: ZapSpacing.md),
          Text(
            actual,
            style: TextStyle(
              color: pass ? ZapColors.safe : ZapColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: pass ? ZapColors.safe : ZapColors.danger,
            size: 14,
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Access Gate ────────────────────────────────────────────────────────
class _AccessGateTab extends ConsumerWidget {
  const _AccessGateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(_d226UnlockedProvider);
    final devFlag = ref.watch(_d226DevFlagProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _StaffBanner(),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How staff access works',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Production: hidden behind long-press on Settings → About → '
                'version label (3s) OR internal dev flag in debug builds. '
                'Requires staff JWT for live API.',
                style: TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgElevated,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: ZapColors.textMuted, size: 18),
                  SizedBox(width: ZapSpacing.sm),
                  Text(
                    'ZapSafe v1.0.0 (226)',
                    style: TextStyle(
                      color: ZapColors.textSecondary,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              Semantics(
                label: 'Simulate long press on About version',
                button: true,
                child: GestureDetector(
                  onLongPress: unlocked
                      ? null
                      : () {
                          _unlock(ref);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Staff mode unlocked (About long-press sim)',
                              ),
                            ),
                          );
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    decoration: BoxDecoration(
                      color: ZapColors.danger.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(
                        color: ZapColors.danger.withOpacity(0.35),
                      ),
                    ),
                    child: const Text(
                      'Long-press here to simulate\nSettings → About version hold',
                      style: TextStyle(
                        color: ZapColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          title: const Text(
            'Dev flag (debug build)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Equivalent to kShowAdminAnalytics = true in dev',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          value: devFlag,
          activeColor: ZapColors.danger,
          onChanged: (v) {
            ref.read(_d226DevFlagProvider.notifier).state = v;
            if (v) {
              _unlock(ref);
            } else if (!unlocked) {
              _lock(ref);
            }
          },
        ),
        if (unlocked) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: ZapColors.safe),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Unlocked — Dashboard tab shows live mock metrics.',
                    style: TextStyle(color: ZapColors.safe, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          TextButton(
            onPressed: () {
              _lock(ref);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Staff mode locked')),
              );
            },
            child: const Text('Lock again'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 2: API Contract ───────────────────────────────────────────────────────
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: ZapColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GET',
                      style: TextStyle(
                        color: ZapColors.info,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  const Expanded(
                    child: Text(
                      '/api/v1/admin/analytics/summary/',
                      style: TextStyle(
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
              const Text(
                'Authorization: Bearer <staff_jwt> · 403 for non-staff tokens',
                style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            _kApiSample,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy API contract',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: 'GET /api/v1/admin/analytics/summary/\n$_kApiSample',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API contract copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy contract'),
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
            'Tomorrow: Day 231 — Stealth LP24 icon disguise setup.',
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
                        color: selected ? ZapColors.danger : Colors.transparent,
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
