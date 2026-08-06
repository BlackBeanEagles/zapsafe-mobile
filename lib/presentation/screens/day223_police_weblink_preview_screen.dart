/// Day 223 — Police WebLink Preview
///
/// Section B (Days 221-240): in-app styled preview of the police operator
/// web dashboard — map, victim summary, evidence SHA-256 hashes, acknowledge.
///
/// Tag: 🟡 MOCK-NOW — read-only preview; mock acknowledge action for demo.
///
/// Route: [AppRoutes.policeWeblinkPreview] → `/police-weblink-preview`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Mock operator data ────────────────────────────────────────────────────────
const _kReference = 'MP-2026-88421';
const _kSosId = 'sos_a8f3c21e-8842';
const _kVictimName = 'Priya Sharma';
const _kVictimPhone = '+91 98765 43210';
const _kDepartment = 'Mumbai Police Cyber Cell';
const _kLat = 19.0760;
const _kLng = 72.8777;
const _kLocationLabel = 'Bandra West, Mumbai · accuracy 8m';

const _kEvidenceHashes = [
  (
    'audio_alert_12s.wav',
    'sha256:a3f2918c…e4b2',
    '12s · recorded 10:41:02',
    Icons.mic_rounded,
  ),
  (
    'vault_photo_01.jpg',
    'sha256:b91c44fa…9d01',
    'Front camera · tamper-sealed',
    Icons.photo_camera_rounded,
  ),
  (
    'gps_track.json',
    'sha256:c44e7712…3aa8',
    '14 pings · last 10:41:55',
    Icons.location_on_rounded,
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d223TabProvider = StateProvider<int>((ref) => 0);
final _d223AcknowledgedProvider = StateProvider<bool>((ref) => false);
final _d223AckLoadingProvider = StateProvider<bool>((ref) => false);
final _d223AckTimeProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Operator View', 'Evidence', 'Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day223PoliceWeblinkPreviewScreen extends ConsumerWidget {
  const Day223PoliceWeblinkPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d223TabProvider);
    final acknowledged = ref.watch(_d223AcknowledgedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 223 · Police WebLink'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
                ),
                child: Text(
                  acknowledged ? 'ACKED' : 'PREVIEW',
                  style: TextStyle(
                    color: acknowledged ? ZapColors.safe : ZapColors.danger,
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
            onSelect: (i) => ref.read(_d223TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _OperatorViewTab(),
              1 => const _EvidenceTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _mockAcknowledge(WidgetRef ref) async {
  ref.read(_d223AckLoadingProvider.notifier).state = true;
  await Future<void>.delayed(const Duration(milliseconds: 850));
  ref.read(_d223AckLoadingProvider.notifier).state = false;
  ref.read(_d223AcknowledgedProvider.notifier).state = true;
  final now = DateTime.now();
  ref.read(_d223AckTimeProvider.notifier).state =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
}

void _resetAck(WidgetRef ref) {
  ref.read(_d223AcknowledgedProvider.notifier).state = false;
  ref.read(_d223AckTimeProvider.notifier).state = null;
  ref.read(_d223AckLoadingProvider.notifier).state = false;
}

// ── Tab 0: Operator view ──────────────────────────────────────────────────────
class _OperatorViewTab extends ConsumerWidget {
  const _OperatorViewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acknowledged = ref.watch(_d223AcknowledgedProvider);
    final loading = ref.watch(_d223AckLoadingProvider);
    final ackTime = ref.watch(_d223AckTimeProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PreviewModeBanner(),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.local_police_rounded, size: 16),
              label: const Text('Day 221'),
              onPressed: () => context.push(AppRoutes.policeDashboard),
            ),
            ActionChip(
              avatar: const Icon(Icons.timeline_rounded, size: 16),
              label: const Text('Day 222 Dispatch'),
              onPressed: () => context.push(AppRoutes.policeDispatchStatus),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2332),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _MapGridPainter(),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin,
                        color: ZapColors.danger.withOpacity(0.9), size: 36),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '$_kLat, $_kLng',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE MAP · read-only',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          _kLocationLabel,
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _InfoCard(
          title: 'Victim summary',
          children: [
            _InfoRow(label: 'Name', value: _kVictimName),
            _InfoRow(label: 'Phone', value: _kVictimPhone),
            _InfoRow(label: 'SOS ID', value: _kSosId, mono: true),
            _InfoRow(label: 'Reference', value: _kReference, mono: true),
            _InfoRow(label: 'Status', value: 'ALERT_ACTIVE'),
            _InfoRow(label: 'Battery', value: '23%'),
            _InfoRow(label: 'Department', value: _kDepartment),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        _InfoCard(
          title: 'Evidence hashes (verify only)',
          children: [
            for (final item in _kEvidenceHashes.take(2))
              _HashRow(
                name: item.$1,
                hash: item.$2,
                meta: item.$3,
                icon: item.$4,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref.read(_d223TabProvider.notifier).state = 1,
                child: const Text('View all 3 hashes →'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (acknowledged) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: ZapColors.safe, size: 22),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Acknowledged by Officer Singh · $ackTime IST',
                    style: const TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton(
            onPressed: () => _resetAck(ref),
            child: const Text('Reset acknowledge (demo)'),
          ),
        ] else ...[
          Semantics(
            label: 'Acknowledge SOS alert',
            button: true,
            child: FilledButton.icon(
              onPressed: loading ? null : () => _mockAcknowledge(ref),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                loading ? 'Acknowledging…' : 'Acknowledge alert',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 75),
                backgroundColor: ZapColors.danger,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Mock operator action — marks dispatch as received in Cyber Cell console.',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _PreviewModeBanner extends StatelessWidget {
  const _PreviewModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.danger.withOpacity(0.55), width: 2),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_rounded, color: ZapColors.danger, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POLICE VIEW — PREVIEW MODE',
                  style: TextStyle(
                    color: ZapColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Styled Flutter mock of operator WebLink · not a live WebView',
                  style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String name;
  final String hash;
  final String meta;
  final IconData icon;

  const _HashRow({
    required this.name,
    required this.hash,
    required this.meta,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZapColors.info, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  hash,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
                Text(
                  meta,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Copy hash for $name',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              color: ZapColors.textMuted,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied hash for $name')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A3544)
      ..strokeWidth = 1;
    const step = 24.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final road = Paint()
      ..color = const Color(0xFF3D4F63)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.45),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.4, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Tab 1: Evidence ───────────────────────────────────────────────────────────
class _EvidenceTab extends ConsumerWidget {
  const _EvidenceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PreviewModeBanner(),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Tamper-evident hash list',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Police operators verify integrity — raw vault files require warrant.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kEvidenceHashes.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: _HashRow(
              name: e.$1,
              hash: e.$2,
              meta: e.$3,
              icon: e.$4,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'Contact WebLink (Tier 1/2) shows map + status only. '
            'Police WebLink adds evidence hashes + acknowledge for Cyber Cell.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const spec = '''Day 223 — Police WebLink Preview

Operator console (web) — victim app shows read-only mock:
• Banner: POLICE VIEW — PREVIEW MODE
• Live map pin + last known coordinates
• Victim summary (name, phone, SOS ref, battery)
• Evidence SHA-256 hashes (verify, not download)
• Acknowledge button → dispatch queue

Mock API (future):
POST /api/v1/police/dispatch/{sos_id}/acknowledge/
Response 200 { "acknowledged_at": "...", "officer_id": "..." }

Parallel: contact WebLink for Tier 1/2 (map only, no hashes).''';

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
            '🟡 MOCK-NOW · Section B Day 3/20 · styled preview (not WebView)',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
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
          child: const SelectableText(
            spec,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy spec',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: spec));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Spec copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy spec'),
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
            'Tomorrow: Day 225 — Referral rewards & leaderboard tie-in.',
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
