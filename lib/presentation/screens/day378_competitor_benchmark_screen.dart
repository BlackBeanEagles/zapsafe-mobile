/// Day 378 — Competitor Benchmark Update
///
/// Section N (Days 371-380, Scale & Stabilize): a feature matrix vs
/// Life360, Noonlight, and bSafe.
///
/// Uses real general knowledge of each named competitor's real feature
/// set. Where a specific detail (current tier name, exact current
/// pricing) isn't confidently known, it is marked "needs verification"
/// rather than guessed — no fictional features invented for real named
/// companies.
///
/// ZapSafe's own column is grepped from real shipped code in this repo,
/// not aspirational: DCS audio detection (real `model_registry.dart`
/// slots — scream/motion/scene/fusion/aggressive_speech), IMU fall
/// detection (`day36_imu_service_screen.dart`), GPS adaptive cadence +
/// cell/WiFi fallback (`day37_gps_service_screen.dart`,
/// `day38`-era fallback coordinator), duress PIN (Day 39's
/// `PinPolicy`), Evidence Vault (`day82_evidence_vault_screen.dart`,
/// `day309_evidence_vault_search_screen.dart`), Offline SOS
/// (`day245_offline_sos_ux_screen.dart`), Fake Call
/// (`day244_fake_call_polish_screen.dart`), Journey Mode / Ride Safety
/// (`day241`/`day243`), Group Journey panic button (Day 357, real
/// endpoint), and 25-language support (Section J, Days 341-350).
///
/// Tag: 🟢 real feature matrix — competitor knowledge from training data
/// hedged honestly, ZapSafe column grepped from real shipped code.
///
/// Route: [AppRoutes.competitorBenchmark] → `/day-378-competitor-benchmark`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0D9488);

enum _Support { yes, no, partial, needsVerification }

class _FeatureRow {
  const _FeatureRow({required this.feature, required this.life360, required this.noonlight, required this.bsafe, required this.zapsafe, required this.zapsafeNote});
  final String feature;
  final _Support life360;
  final _Support noonlight;
  final _Support bsafe;
  final _Support zapsafe;
  final String zapsafeNote;
}

const _kMatrix = [
  _FeatureRow(
    feature: 'Real-time family location sharing',
    life360: _Support.yes,
    noonlight: _Support.no,
    bsafe: _Support.partial,
    zapsafe: _Support.yes,
    zapsafeNote: 'Trusted Circle + GPS adaptive cadence (day37).',
  ),
  _FeatureRow(
    feature: 'Geofenced place alerts (arrival/departure)',
    life360: _Support.yes,
    noonlight: _Support.no,
    bsafe: _Support.no,
    zapsafe: _Support.partial,
    zapsafeNote: 'Trusted locations exist (onboarding step 3); full arrive/leave geofence alerting not confirmed shipped.',
  ),
  _FeatureRow(
    feature: 'AI/ML-based automatic distress detection (audio+motion)',
    life360: _Support.no,
    noonlight: _Support.no,
    bsafe: _Support.no,
    zapsafe: _Support.yes,
    zapsafeNote: 'Real DCS fusion — scream/motion/scene/fusion/aggressive_speech models, on-device.',
  ),
  _FeatureRow(
    feature: 'Automatic crash detection',
    life360: _Support.yes,
    noonlight: _Support.needsVerification,
    bsafe: _Support.no,
    zapsafe: _Support.partial,
    zapsafeNote: 'IMU fall detector (day36) covers falls; vehicle-crash-specific model exists in ML retrain history (DAY271) — on-device wiring not fully confirmed in this pass.',
  ),
  _FeatureRow(
    feature: 'Direct professional 24/7 monitoring & dispatch',
    life360: _Support.partial,
    noonlight: _Support.yes,
    bsafe: _Support.no,
    zapsafe: _Support.partial,
    zapsafeNote: 'Police dispatch endpoint is real but honestly mock-shaped (is_mock: true) until a real police integration exists.',
  ),
  _FeatureRow(
    feature: 'Silent/duress trigger (won\'t alert an attacker)',
    life360: _Support.no,
    noonlight: _Support.yes,
    bsafe: _Support.partial,
    zapsafe: _Support.yes,
    zapsafeNote: 'Duress PIN + LP3 silent-escalation flag (Day 39, real security-matrix feature).',
  ),
  _FeatureRow(
    feature: 'Fake incoming call (decoy to exit a situation)',
    life360: _Support.no,
    noonlight: _Support.no,
    bsafe: _Support.yes,
    zapsafe: _Support.yes,
    zapsafeNote: 'day244_fake_call_polish_screen.dart.',
  ),
  _FeatureRow(
    feature: 'Live audio/video streaming to guardians during SOS',
    life360: _Support.no,
    noonlight: _Support.needsVerification,
    bsafe: _Support.yes,
    zapsafe: _Support.no,
    zapsafeNote: 'Not found in this repo — Evidence Vault records locally, not livestreamed.',
  ),
  _FeatureRow(
    feature: 'Offline / no-signal SOS (SMS fallback)',
    life360: _Support.no,
    noonlight: _Support.needsVerification,
    bsafe: _Support.no,
    zapsafe: _Support.yes,
    zapsafeNote: 'day245_offline_sos_ux_screen.dart.',
  ),
  _FeatureRow(
    feature: 'Local encrypted evidence vault (photo/audio/video)',
    life360: _Support.no,
    noonlight: _Support.no,
    bsafe: _Support.no,
    zapsafe: _Support.yes,
    zapsafeNote: 'day82_evidence_vault_screen.dart + day309 search.',
  ),
  _FeatureRow(
    feature: 'Group/multi-person journey tracking with shared panic',
    life360: _Support.partial,
    noonlight: _Support.no,
    bsafe: _Support.yes,
    zapsafe: _Support.yes,
    zapsafeNote: 'Day 357 group journey — real endpoints, panic creates a real SOSEvent per member.',
  ),
  _FeatureRow(
    feature: 'Driving behavior reports (speed, hard braking, phone use)',
    life360: _Support.yes,
    noonlight: _Support.no,
    bsafe: _Support.no,
    zapsafe: _Support.no,
    zapsafeNote: 'Not built — closest is Day 243 Ride Safety, not a full driving-report product.',
  ),
  _FeatureRow(
    feature: 'Third-party integration ecosystem (Uber/ADT/etc.)',
    life360: _Support.needsVerification,
    noonlight: _Support.yes,
    bsafe: _Support.no,
    zapsafe: _Support.no,
    zapsafeNote: 'Not built. Day 352\'s insurance API wire is confirmed mock, no third-party integrations exist.',
  ),
  _FeatureRow(
    feature: '25+ language localization',
    life360: _Support.needsVerification,
    noonlight: _Support.no,
    bsafe: _Support.needsVerification,
    zapsafe: _Support.yes,
    zapsafeNote: 'Section J (Days 341-350) — 25-language completion.',
  ),
  _FeatureRow(
    feature: 'Identity theft / credit monitoring add-on',
    life360: _Support.yes,
    noonlight: _Support.no,
    bsafe: _Support.no,
    zapsafe: _Support.no,
    zapsafeNote: 'Not built, not planned.',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day378CompetitorBenchmarkScreen extends ConsumerWidget {
  const Day378CompetitorBenchmarkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.competitor_benchmark_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.compare_arrows_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Uses real general knowledge of Life360, Noonlight, and '
                    'bSafe\'s real feature sets. Uncertain specifics are marked '
                    '"needs verification" rather than guessed. ZapSafe\'s column '
                    'is grepped from real shipped code, not aspirational.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const _Legend(),
          const SizedBox(height: ZapSpacing.xl),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    _HeaderCell('Feature', width: 260),
                    _HeaderCell('Life360', width: 90),
                    _HeaderCell('Noonlight', width: 90),
                    _HeaderCell('bSafe', width: 90),
                    _HeaderCell('ZapSafe', width: 90),
                  ],
                ),
                const Divider(color: ZapColors.border),
                for (final row in _kMatrix) _MatrixRow(row: row),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 6, children: const [
      _LegendChip(icon: Icons.check_circle_rounded, color: ZapColors.safe, label: 'Yes'),
      _LegendChip(icon: Icons.remove_circle_outline_rounded, color: ZapColors.textMuted, label: 'No'),
      _LegendChip(icon: Icons.adjust_rounded, color: ZapColors.warning, label: 'Partial'),
      _LegendChip(icon: Icons.help_outline_rounded, color: ZapColors.info, label: 'Needs verification'),
    ]);
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: ZapColors.textMuted, fontSize: 11)),
    ]);
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.width});
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({required this.row});
  final _FeatureRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 260,
            child: Text(row.feature, style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.3)),
          ),
          SizedBox(width: 90, child: _SupportIcon(row.life360)),
          SizedBox(width: 90, child: _SupportIcon(row.noonlight)),
          SizedBox(width: 90, child: _SupportIcon(row.bsafe)),
          SizedBox(
            width: 90,
            child: Tooltip(
              message: row.zapsafeNote,
              child: _SupportIcon(row.zapsafe),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportIcon extends StatelessWidget {
  const _SupportIcon(this.support);
  final _Support support;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (support) {
      _Support.yes => (Icons.check_circle_rounded, ZapColors.safe),
      _Support.no => (Icons.remove_circle_outline_rounded, ZapColors.textMuted),
      _Support.partial => (Icons.adjust_rounded, ZapColors.warning),
      _Support.needsVerification => (Icons.help_outline_rounded, ZapColors.info),
    };
    return Icon(icon, color: color, size: 18);
  }
}
