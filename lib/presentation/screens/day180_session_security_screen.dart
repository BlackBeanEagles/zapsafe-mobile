/// Day 180 — Session Security, Trusted Devices & Section B Sign-Off
///
/// Final day of Section B (Data Rights, Days 166-180).
/// Day 179: Active sessions — 4 devices, remote sign-out, login history  ✅
/// Day 180: Trusted devices, session expiry config, suspicious-login
///           push alerts, Section B complete sign-off, Section C preview.
///
/// 🟡 MOCK-NOW — backend session-security API does not exist yet.
///    Section C (Days 181-190): Security Hardening — all 🟢 FRONTEND-ONLY.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d180TabProvider          = StateProvider<int>((ref) => 0);
// Trusted devices
final _trustedDevicesProvider   = StateProvider<Set<String>>((ref) =>
    {'sess_s24_current', 'sess_pixel_work'});
final _trustingProvider         = StateProvider<String?>((ref) => null);
// Session expiry
final _expiryDaysProvider       = StateProvider<int>((ref) => 30);
final _saveExpiryStateProvider  = StateProvider<_SaveState>((ref) => _SaveState.idle);
// Alert settings
final _newDeviceAlertProvider   = StateProvider<bool>((ref) => true);
final _failedAttemptsAlertProvider = StateProvider<bool>((ref) => true);
final _geoAnomalyAlertProvider  = StateProvider<bool>((ref) => true);
final _failThresholdProvider    = StateProvider<int>((ref) => 3);
final _saveAlertStateProvider   = StateProvider<_SaveState>((ref) => _SaveState.idle);

enum _SaveState { idle, saving, saved }

// ── Device data (reusing Day 179's sessions) ──────────────────────────────────
class _DeviceRecord {
  final String   id;
  final String   name;
  final String   type;   // 'Android' | 'iOS'
  final String   os;
  final String   city;
  final DateTime lastSeen;
  final bool     isCurrent;
  final bool     suspicious;
  const _DeviceRecord({
    required this.id, required this.name, required this.type,
    required this.os, required this.city, required this.lastSeen,
    this.isCurrent = false, this.suspicious = false,
  });
}

final _kDevices = [
  _DeviceRecord(
    id: 'sess_s24_current', name: 'Samsung Galaxy S24',
    type: 'Android', os: 'Android 14', city: 'Mumbai',
    lastSeen: DateTime(2026, 5, 30, 14, 30), isCurrent: true,
  ),
  _DeviceRecord(
    id: 'sess_ipad_suspicious', name: 'iPad Air (5th gen)',
    type: 'iOS', os: 'iPadOS 17.4', city: 'Pune',
    lastSeen: DateTime(2026, 5, 25, 16, 30), suspicious: true,
  ),
  _DeviceRecord(
    id: 'sess_pixel_work', name: 'Pixel 7 (Work)',
    type: 'Android', os: 'Android 14', city: 'Mumbai',
    lastSeen: DateTime(2026, 5, 12, 18, 0),
  ),
  _DeviceRecord(
    id: 'sess_s24_old', name: 'Samsung Galaxy S24 (old session)',
    type: 'Android', os: 'Android 14', city: 'Mumbai',
    lastSeen: DateTime(2026, 3, 10, 12, 0),
  ),
];

// ── Section B summary ─────────────────────────────────────────────────────────
const _kSectionBBlocks = [
  ('Days 166-168', 'Data Export / Download My Data',
      '3 screens · DPDP §11 + GDPR Art.20 · ZIP/JSON/PDF · 4 API endpoints',
      Color(0xFF8B5CF6)),
  ('Days 169-172', 'Account Deletion Flow',
      '4 screens · DPDP §13 + GDPR Art.17 · 30-day grace · 5 API endpoints',
      Color(0xFFEF4444)),
  ('Days 173-175', 'Data Access Audit Log',
      '3 screens · DPDP §11(1)(a/b) · 30 events · CSV/PDF export · 3 API endpoints',
      Color(0xFF3B82F6)),
  ('Days 176-178', 'Data Retention Settings',
      '3 screens · DPDP §8 · 7 categories · scheduler · 4 API endpoints',
      Color(0xFF10B981)),
  ('Days 179-180', 'Active Sessions / Devices',
      '2 screens · Trusted devices · Geo-anomaly detection · 4 API endpoints',
      Color(0xFF3B82F6)),
];

// ── Section C preview ─────────────────────────────────────────────────────────
const _kSectionCPreview = [
  ('Days 181-182', '🟢 FRONTEND-ONLY',
      'Certificate pinning screen + network security config viewer'),
  ('Days 183-184', '🟢 FRONTEND-ONLY',
      'Biometric lock screen + LP18 gate strengthening'),
  ('Days 185-186', '🟢 FRONTEND-ONLY',
      'Jailbreak / root detection + tamper alerts'),
  ('Days 187-188', '🟢 FRONTEND-ONLY',
      'Secure storage audit + Hive encryption key rotation'),
  ('Days 189-190', '🟢 FRONTEND-ONLY',
      'Security dashboard + Section C complete sign-off'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day180SessionSecurityScreen extends ConsumerWidget {
  const Day180SessionSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d180TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Session Security & Sign-Off'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Text('SECTION B ✅',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_d180TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _TrustedDevicesTab(),
            if (tab == 1) const _AlertsTab(),
            if (tab == 2) const _SectionBCompleteTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.04),
          const Color(0xFF0A0A0A),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.55), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 180',                   const Color(0xFF10B981)),
          _badge('🟡 MOCK-NOW',                   const Color(0xFFF59E0B)),
          _badge('Section B  ·  FINAL DAY 🎉',    const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Trusted Devices,\nSecurity Alerts & Section B Done',
            style: TextStyle(color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Mark trusted devices to suppress false alerts. '
          'Configure JWT expiry (30–180 days). '
          'Set push alerts for suspicious logins. '
          'Section B — 15 days, 5 blocks, Data Rights complete.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('4',    '4 devices',          Color(0xFF3B82F6)),
          _HStat('3',    'Alert types',        Color(0xFFF59E0B)),
          _HStat('5',    'Section B blocks',   Color(0xFF10B981)),
          _HStat('15d',  'Section B days',     Color(0xFF8B5CF6)),
        ]),
      ]));

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 13,
        fontWeight: FontWeight.w800), textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_rounded,  Color(0xFF3B82F6), 'Trusted Devices'),
      (Icons.notifications_active_rounded, Color(0xFFF59E0B), 'Security Alerts'),
      (Icons.emoji_events_rounded,   Color(0xFF10B981), 'Section B Done'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1)),
          child: Column(children: [
            Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
            const SizedBox(height: ZapSpacing.xs),
            Text(label, style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Trusted Devices + Session Expiry
// ══════════════════════════════════════════════════════════════════════════════
class _TrustedDevicesTab extends ConsumerWidget {
  const _TrustedDevicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trusted   = ref.watch(_trustedDevicesProvider);
    final trusting  = ref.watch(_trustingProvider);
    final expiry    = ref.watch(_expiryDaysProvider);
    final saveState = ref.watch(_saveExpiryStateProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.verified_user_rounded, color: const Color(0xFF3B82F6),
          text: 'Trusted devices skip the "new device" security alert. '
              'Only trust devices you personally own. '
              'Suspicious or unrecognised devices should NOT be trusted — '
              'sign them out instead.'),
      const SizedBox(height: ZapSpacing.lg),

      // Trusted device count
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${trusted.length} trusted devices',
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
            Text('${_kDevices.length - trusted.length} untrusted — '
                'new-device alerts active for these',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
          ])),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Device trust list
      const _SectionLabel('4 DEVICES  ·  TAP SHIELD TO TRUST / UNTRUST'),
      const SizedBox(height: ZapSpacing.md),

      ..._kDevices.map((device) {
        final isTrusted    = trusted.contains(device.id);
        final isTrusting   = trusting == device.id;
        final deviceColor  = device.suspicious
            ? const Color(0xFFEF4444)
            : device.isCurrent
                ? const Color(0xFF10B981)
                : const Color(0xFF3B82F6);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: isTrusted
                  ? const Color(0xFF10B981).withOpacity(0.06)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isTrusted
                      ? const Color(0xFF10B981).withOpacity(0.35)
                      : const Color(0xFF2A2A2A),
                  width: isTrusted ? 2 : 1)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: deviceColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(
                device.type == 'iOS' ? Icons.apple_rounded : Icons.android_rounded,
                color: deviceColor, size: 18)),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(device.name, style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                if (device.isCurrent)
                  _tag('CURRENT', const Color(0xFF10B981))
                else if (device.suspicious)
                  _tag('⚠ SUSPICIOUS', const Color(0xFFEF4444)),
              ]),
              Text('${device.city}  ·  ${device.os}  ·  '
                  '${_relTime(device.lastSeen)}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            ])),
            const SizedBox(width: ZapSpacing.md),
            // Trust toggle
            if (isTrusting)
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(
                  color: Color(0xFF10B981), strokeWidth: 2))
            else
              GestureDetector(
                onTap: device.suspicious
                    ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Cannot trust a suspicious device — sign it out first.'),
                        backgroundColor: Color(0xFFEF4444)))
                    : () => _toggleTrust(ref, context, device.id, isTrusted),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: isTrusted
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFF1A1A1A),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: device.suspicious
                              ? const Color(0xFF3A3A3A)
                              : isTrusted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF3A3A3A),
                          width: 2)),
                  child: Icon(
                    isTrusted
                        ? Icons.verified_user_rounded
                        : Icons.shield_outlined,
                    color: device.suspicious
                        ? const Color(0xFF3A3A3A)
                        : isTrusted
                            ? const Color(0xFF10B981)
                            : const Color(0xFF4B5563),
                    size: 18)),
              ),
          ]),
        );
      }),
      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: 'Trusting a device only affects alert suppression. '
              'Revocation and sign-out work independently regardless of trust status.'),

      const SizedBox(height: ZapSpacing.xl),
      const Divider(color: Color(0xFF1E1E1E)),
      const SizedBox(height: ZapSpacing.xl),

      // Session expiry picker
      const _SectionLabel('JWT SESSION EXPIRY'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.timer_rounded, color: const Color(0xFF8B5CF6),
          text: 'How long before a JWT expires and requires re-login. '
              'Shorter = more secure. Longer = less friction. '
              '30 days is ZapSafe\'s default (balances security + usability).'),
      const SizedBox(height: ZapSpacing.lg),

      // Expiry slider
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.vpn_key_rounded, color: Color(0xFF8B5CF6), size: 16),
            const SizedBox(width: ZapSpacing.sm),
            const Text('Session expires after:',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            const Spacer(),
            Text(expiry == 180 ? '180 days (max)' : '$expiry days',
                style: const TextStyle(color: Color(0xFF8B5CF6),
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          Slider(
            value: expiry.toDouble(),
            min: 7, max: 180,
            divisions: 5, // 7, 14, 30, 60, 90, 180
            activeColor: const Color(0xFF8B5CF6),
            inactiveColor: const Color(0xFF2A2A2A),
            onChanged: (v) {
              // Snap to allowed values
              const allowed = [7, 14, 30, 60, 90, 180];
              final closest = allowed.reduce((a, b) =>
                  (a - v).abs() < (b - v).abs() ? a : b);
              ref.read(_expiryDaysProvider.notifier).state = closest;
            },
          ),
          // Labels
          const Row(children: [
            Text('7d', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            Spacer(),
            Text('14d', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            Spacer(),
            Text('30d', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            Spacer(),
            Text('60d', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            Spacer(),
            Text('90d', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
            Spacer(),
            Text('180d', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          // Security level indicator
          _ExpirySecurityBar(expiry: expiry),
        ]),
      ),
      const SizedBox(height: ZapSpacing.md),
      if (saveState == _SaveState.idle)
        _primaryBtn(
          label: 'Save Expiry Setting  (Mock)',
          color: const Color(0xFF8B5CF6),
          onTap: () => _saveExpiry(context, ref),
        )
      else if (saveState == _SaveState.saving)
        _statusCard(Icons.hourglass_top_rounded, const Color(0xFF8B5CF6),
            'Saving…', 'PUT /api/v1/account/session-config', loading: true)
      else
        _statusCard(Icons.check_circle_rounded, const Color(0xFF10B981),
            'Saved ✅', 'Session expiry updated to $expiry days. '
            'Existing sessions are unaffected — new sessions use the new setting.',
            loading: false),
    ]);
  }

  static Widget _tag(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w800)));

  static String _relTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 30)     return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).round()}mo ago';
  }

  Future<void> _toggleTrust(WidgetRef ref, BuildContext context,
      String id, bool currentlyTrusted) async {
    ref.read(_trustingProvider.notifier).state = id;
    await Future.delayed(const Duration(milliseconds: 600));
    final updated = Set<String>.from(ref.read(_trustedDevicesProvider));
    if (currentlyTrusted) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    ref.read(_trustedDevicesProvider.notifier).state = updated;
    ref.read(_trustingProvider.notifier).state = null;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(currentlyTrusted ? 'Device untrusted' : 'Device trusted ✅'),
          backgroundColor: currentlyTrusted
              ? const Color(0xFF6B7280) : const Color(0xFF10B981),
          duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _saveExpiry(BuildContext context, WidgetRef ref) async {
    ref.read(_saveExpiryStateProvider.notifier).state = _SaveState.saving;
    await Future.delayed(const Duration(milliseconds: 900));
    if (context.mounted) {
      ref.read(_saveExpiryStateProvider.notifier).state = _SaveState.saved;
    }
  }
}

class _ExpirySecurityBar extends StatelessWidget {
  final int expiry;
  const _ExpirySecurityBar({required this.expiry});

  @override
  Widget build(BuildContext context) {
    final (label, color, desc) = switch (expiry) {
      <= 14  => ('Very Secure', const Color(0xFF10B981),
                 'Sessions expire quickly. Users re-login more often.'),
      <= 30  => ('Secure (recommended)', const Color(0xFF10B981),
                 'ZapSafe default. Good balance of security and convenience.'),
      <= 60  => ('Moderate', const Color(0xFFF59E0B),
                 'Slightly more risk if a device is lost or compromised.'),
      <= 90  => ('Low', const Color(0xFFF59E0B),
                 'Longer exposure window if JWT is compromised.'),
      _      => ('Minimal Security', const Color(0xFFEF4444),
                 'JWT valid for 6 months. Not recommended for safety apps.'),
    };
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall)),
      child: Row(children: [
        Icon(Icons.security_rounded, color: color, size: 13),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
          Text(desc, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9, height: 1.4)),
        ])),
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Security Alerts
// ══════════════════════════════════════════════════════════════════════════════
class _AlertsTab extends ConsumerWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newDevice  = ref.watch(_newDeviceAlertProvider);
    final failed     = ref.watch(_failedAttemptsAlertProvider);
    final geo        = ref.watch(_geoAnomalyAlertProvider);
    final threshold  = ref.watch(_failThresholdProvider);
    final saveState  = ref.watch(_saveAlertStateProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.notifications_active_rounded, color: const Color(0xFFF59E0B),
          text: 'ZapSafe sends push notifications when suspicious sign-in '
              'activity is detected. Configure which events trigger an alert.'),
      const SizedBox(height: ZapSpacing.lg),

      // Alert toggles
      const _SectionLabel('SECURITY ALERT TYPES'),
      const SizedBox(height: ZapSpacing.md),

      _AlertToggle(
        icon: Icons.devices_rounded,
        color: const Color(0xFF3B82F6),
        title: 'New device sign-in',
        subtitle: 'Alert when your account is accessed from a device '
            'not in your trusted devices list.',
        value: newDevice,
        onChanged: (v) => ref.read(_newDeviceAlertProvider.notifier).state = v,
        mockAlert: _mockAlert(
          icon: Icons.devices_rounded,
          color: const Color(0xFF3B82F6),
          title: '🔐 New device signed in',
          body: 'ZapSafe was opened on iPad Air from Pune, India. '
              'Not you? Sign out this session immediately.',
        ),
      ),
      const SizedBox(height: ZapSpacing.sm),

      _AlertToggle(
        icon: Icons.block_rounded,
        color: const Color(0xFFEF4444),
        title: 'Failed sign-in attempts',
        subtitle: 'Alert after $threshold consecutive failed OTP attempts on your number.',
        value: failed,
        onChanged: (v) => ref.read(_failedAttemptsAlertProvider.notifier).state = v,
        mockAlert: _mockAlert(
          icon: Icons.block_rounded,
          color: const Color(0xFFEF4444),
          title: '⚠️ Failed sign-in attempts',
          body: '3 failed OTP attempts from Hyderabad, India. '
              'If this wasn\'t you, your number may be targeted.',
        ),
      ),
      const SizedBox(height: ZapSpacing.sm),

      _AlertToggle(
        icon: Icons.travel_explore_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Geographic anomaly',
        subtitle: 'Alert when a sign-in occurs from a city outside your primary location.',
        value: geo,
        onChanged: (v) => ref.read(_geoAnomalyAlertProvider.notifier).state = v,
        mockAlert: _mockAlert(
          icon: Icons.travel_explore_rounded,
          color: const Color(0xFFF59E0B),
          title: '📍 Sign-in from new location',
          body: 'ZapSafe was signed in from Pune, India. '
              'Your primary city is Mumbai. Not you? Act now.',
        ),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Failed attempts threshold
      const _SectionLabel('FAILED ATTEMPTS THRESHOLD'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            const Text('Alert after:', style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 11)),
            const Spacer(),
            Text('$threshold failed attempt${threshold == 1 ? "" : "s"}',
                style: const TextStyle(color: Color(0xFFEF4444),
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: List.generate(5, (i) {
            final val = i + 1;
            final isSelected = val == threshold;
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
              child: GestureDetector(
                onTap: () => ref.read(_failThresholdProvider.notifier).state = val,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEF4444).withOpacity(0.12)
                          : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFFEF4444).withOpacity(0.5)
                              : const Color(0xFF2A2A2A),
                          width: isSelected ? 2 : 1)),
                  child: Center(child: Text('$val',
                      style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                          fontSize: 13, fontWeight: isSelected
                              ? FontWeight.w800 : FontWeight.w400)))),
              )));
          })),
          const SizedBox(height: 6),
          const Text('Lower = faster alert, more notifications. '
              'Higher = fewer alerts, wider attack window.',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9, height: 1.4)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Mock notification preview
      const _SectionLabel('ALERT DELIVERY'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _deliveryRow(Icons.notifications_rounded, const Color(0xFF3B82F6),
              'Push notification', 'Delivered to all trusted devices immediately'),
          const Divider(height: 16, color: Color(0xFF222222)),
          _deliveryRow(Icons.email_rounded, const Color(0xFF8B5CF6),
              'Email', 'Sent to account email address as backup'),
          const Divider(height: 16, color: Color(0xFF222222)),
          _deliveryRow(Icons.timer_rounded, const Color(0xFFF59E0B),
              'Cool-down', '5 minutes between alerts of the same type (no spam)'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Save button
      if (saveState == _SaveState.idle)
        _primaryBtn(
          label: 'Save Alert Settings  (Mock)',
          color: const Color(0xFFF59E0B),
          onTap: () => _saveAlerts(context, ref),
        )
      else if (saveState == _SaveState.saving)
        _statusCard(Icons.hourglass_top_rounded, const Color(0xFFF59E0B),
            'Saving…',
            'PUT /api/v1/account/security-alerts', loading: true)
      else
        _statusCard(Icons.check_circle_rounded, const Color(0xFF10B981),
            'Alert settings saved ✅',
            '${[if (newDevice) "New device", if (failed) "Failed attempts", if (geo) "Geo anomaly"].join(" · ")} alerts active.',
            loading: false),
    ]);
  }

  static Widget _mockAlert({required IconData icon, required Color color,
      required String title, required String body}) =>
      Container(
        margin: const EdgeInsets.only(top: ZapSpacing.sm),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 14)),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ZapSafe', style: TextStyle(color: color, fontSize: 9,
                  fontWeight: FontWeight.w700)),
              Text(title, style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
            const Text('now', style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
          ]),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
              fontSize: 10, height: 1.4)),
        ]));

  static Widget _deliveryRow(IconData icon, Color color, String label, String detail) =>
      Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.w600)),
          Text(detail, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
        ])),
      ]);

  Future<void> _saveAlerts(BuildContext context, WidgetRef ref) async {
    ref.read(_saveAlertStateProvider.notifier).state = _SaveState.saving;
    await Future.delayed(const Duration(milliseconds: 800));
    if (context.mounted) {
      ref.read(_saveAlertStateProvider.notifier).state = _SaveState.saved;
    }
  }
}

class _AlertToggle extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, subtitle;
  final bool value; final ValueChanged<bool> onChanged;
  final Widget mockAlert;
  const _AlertToggle({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.value,
    required this.onChanged, required this.mockAlert,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: value ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
              color: value ? color.withOpacity(0.35) : const Color(0xFF2A2A2A),
              width: value ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
          ])),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 26,
              decoration: BoxDecoration(
                  color: value ? color : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(13)),
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: value ? 22 : 2, top: 2,
                  child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle))),
              ])),
          ),
        ]),
        // Mock push notification preview (only when enabled)
        if (value) mockAlert,
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Section B Complete
// ══════════════════════════════════════════════════════════════════════════════
class _SectionBCompleteTab extends StatelessWidget {
  const _SectionBCompleteTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Grand celebration
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.15),
          const Color(0xFF3B82F6).withOpacity(0.08),
          const Color(0xFF10B981).withOpacity(0.03),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 2),
      ),
      child: const Column(children: [
        Text('🎉', style: TextStyle(fontSize: 52)),
        SizedBox(height: ZapSpacing.md),
        Text('Section B: Data Rights',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 0.5),
            textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.xs),
        Text('DAYS 166 – 180  ·  COMPLETE ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.sm),
        Text('15 screens  ·  5 blocks  ·  DPDP + GDPR compliant',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: [
          _Chip('Data Export ✅',          Color(0xFF8B5CF6)),
          _Chip('Account Deletion ✅',     Color(0xFFEF4444)),
          _Chip('Audit Log ✅',            Color(0xFF3B82F6)),
          _Chip('Data Retention ✅',       Color(0xFF10B981)),
          _Chip('Active Sessions ✅',      Color(0xFF3B82F6)),
          _Chip('DPDP §11 ✅',            Color(0xFF10B981)),
          _Chip('GDPR Art.17 ✅',         Color(0xFF3B82F6)),
          _Chip('GDPR Art.20 ✅',         Color(0xFF8B5CF6)),
          _Chip('DPDP §8 ✅',             Color(0xFF10B981)),
          _Chip('DPDP §13 ✅',            Color(0xFF3B82F6)),
          _Chip('Trusted devices ✅',      Color(0xFF3B82F6)),
          _Chip('Geo anomaly detection ✅', Color(0xFFF59E0B)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // 5 block summary
    const _SectionLabel('SECTION B  ·  ALL 5 BLOCKS'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: _kSectionBBlocks.asMap().entries.map((e) {
        final i = e.key;
        final (days, title, detail, color) = e.value;
        final isLast = i == _kSectionBBlocks.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(days, style: TextStyle(color: color, fontSize: 10,
                    fontWeight: FontWeight.w700)),
                Text(title, style: const TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(detail, style: const TextStyle(color: Color(0xFF6B7280),
                    fontSize: 10, height: 1.4)),
              ])),
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
            ]),
          ),
          if (!isLast) const Divider(height: 1, color: Color(0xFF222222)),
        ]);
      }).toList()),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Overall progress bar — Section B done
    const _SectionLabel('SECTION PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    const _ProgressCard(
        label: 'Section A — Privacy & Legal (Days 151-165)',
        value: 1.0, color: Color(0xFF10B981), tag: 'Done ✅'),
    const SizedBox(height: ZapSpacing.sm),
    const _ProgressCard(
        label: 'Section B — Data Rights (Days 166-180)',
        value: 1.0, color: Color(0xFF10B981), tag: 'Done ✅'),
    const SizedBox(height: ZapSpacing.sm),
    const _ProgressCard(
        label: 'Section C — Security Hardening (Days 181-190)',
        value: 0.0, color: Color(0xFF3B82F6), tag: 'Next →'),
    const SizedBox(height: ZapSpacing.sm),
    const _ProgressCard(
        label: 'Section D — Store Prep & Polish (Days 191-200)',
        value: 0.0, color: Color(0xFF6B7280), tag: 'Upcoming'),
    const SizedBox(height: ZapSpacing.xl),

    // Section C preview
    const _SectionLabel('NEXT  ·  SECTION C: SECURITY HARDENING (Days 181-190)'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
      child: Column(children: _kSectionCPreview.map((p) {
        final (days, badge, desc) = p;
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(days, style: const TextStyle(color: Color(0xFF3B82F6),
                  fontSize: 8, fontWeight: FontWeight.w800))),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(badge, style: const TextStyle(
                  color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w700))),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(desc, style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4))),
          ]));
      }).toList()),
    ),
    const SizedBox(height: ZapSpacing.md),
    _infoBox(icon: Icons.shield_rounded, color: const Color(0xFF10B981),
        text: 'Section C (Days 181-190) is all 🟢 FRONTEND-ONLY — '
            'no backend API needed. Certificate pinning, biometric hardening, '
            'root detection, Hive encryption — all client-side.'),
  ]);
}

class _ProgressCard extends StatelessWidget {
  final String label, tag;
  final double value; final Color color;
  const _ProgressCard({required this.label, required this.value,
      required this.color, required this.tag});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 10))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(tag, style: TextStyle(color: color, fontSize: 9,
                fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
              value: value,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5)),
      ]));
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w600)));
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 14, offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))));

Widget _statusCard(IconData icon, Color color, String title, String body,
    {required bool loading}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          loading
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(title, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
            fontSize: 11, height: 1.5)),
      ]));

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));
