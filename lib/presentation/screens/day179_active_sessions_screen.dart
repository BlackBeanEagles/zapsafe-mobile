/// Day 179 — Active Sessions & Device Management
///
/// First day of the Days 179-180 Active Sessions / Devices block —
/// the final block of Section B (Data Rights, Days 166-180).
///
/// Day 179: Full active-sessions list — 4 devices, geographic anomaly
///           detection, remote sign-out, sign-out-all, login history.
/// Day 180: Trusted devices, session deep-dive, Section B complete.
///
/// 🟡 MOCK-NOW — backend at Day 78. No /account/sessions API yet.
///    Day 174 Audit Log had a Sessions preview; this is the full screen.
///    API contract documented in Tab 3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d179TabProvider          = StateProvider<int>((ref) => 0);
final _activeSessionsProvider   = StateProvider<List<_Session>>((ref) => _kSessions);
final _expandedSessionProvider  = StateProvider<String?>((ref) => null);
final _signOutStateProvider     = StateProvider<Map<String, _SignOutState>>((ref) => {});
final _signOutAllStateProvider  = StateProvider<_BulkState>((ref) => _BulkState.idle);
final _signOutAllConfirmProvider= StateProvider<bool>((ref) => false);
final _expandedLoginProvider    = StateProvider<int?>((ref) => null);

enum _SignOutState { idle, signing, done }
enum _BulkState   { idle, signing, done }

// ── Session data model ─────────────────────────────────────────────────────────
class _Session {
  final String   id;
  final String   deviceName;
  final String   deviceType;   // 'Android', 'iOS', 'Web'
  final String   os;
  final String   appVersion;
  final String   city;
  final String   country;
  final DateTime startedAt;
  final DateTime lastActiveAt;
  final bool     isCurrent;
  final bool     suspicious;
  final String?  suspiciousReason;
  const _Session({
    required this.id, required this.deviceName, required this.deviceType,
    required this.os, required this.appVersion, required this.city,
    required this.country, required this.startedAt, required this.lastActiveAt,
    this.isCurrent = false, this.suspicious = false, this.suspiciousReason,
  });
}

final _kSessions = [
  _Session(
    id: 'sess_s24_current',
    deviceName: 'Samsung Galaxy S24',
    deviceType: 'Android',
    os: 'Android 14 (API 34)',
    appVersion: 'v1.0.0 (build 150)',
    city: 'Mumbai', country: 'India',
    startedAt: DateTime(2026, 5, 28, 10, 12),
    lastActiveAt: DateTime(2026, 5, 30, 14, 30),
    isCurrent: true,
  ),
  _Session(
    id: 'sess_ipad_suspicious',
    deviceName: 'iPad Air (5th gen)',
    deviceType: 'iOS',
    os: 'iPadOS 17.4',
    appVersion: 'v1.0.0 (build 150)',
    city: 'Pune', country: 'India',
    startedAt: DateTime(2026, 5, 16, 8, 45),
    lastActiveAt: DateTime(2026, 5, 25, 16, 30),
    suspicious: true,
    suspiciousReason: 'Device not previously associated with this account. '
        '3 failed vault PIN attempts recorded from this device on May 25.',
  ),
  _Session(
    id: 'sess_pixel_work',
    deviceName: 'Pixel 7 (Work)',
    deviceType: 'Android',
    os: 'Android 14 (API 34)',
    appVersion: 'v1.0.0 (build 148)',
    city: 'Mumbai', country: 'India',
    startedAt: DateTime(2026, 3, 15, 9, 0),
    lastActiveAt: DateTime(2026, 5, 12, 18, 0),
  ),
  _Session(
    id: 'sess_s24_old',
    deviceName: 'Samsung Galaxy S24 (old session)',
    deviceType: 'Android',
    os: 'Android 14 (API 34)',
    appVersion: 'v0.9.8 (build 135)',
    city: 'Mumbai', country: 'India',
    startedAt: DateTime(2026, 1, 15, 9, 0),
    lastActiveAt: DateTime(2026, 3, 10, 12, 0),
  ),
];

// ── Login history ─────────────────────────────────────────────────────────────
class _LoginEvent {
  final DateTime ts;
  final String   device;
  final String   city;
  final String   method;      // 'OTP', 'Biometric', 'Failed'
  final bool     success;
  final bool     flagged;
  const _LoginEvent({
    required this.ts, required this.device, required this.city,
    required this.method, required this.success, this.flagged = false,
  });
}

final _kLoginHistory = [
  _LoginEvent(ts: DateTime(2026, 5, 28, 10, 12), device: 'Samsung Galaxy S24',
      city: 'Mumbai', method: 'OTP', success: true),
  _LoginEvent(ts: DateTime(2026, 5, 25, 16, 31), device: 'iPad Air',
      city: 'Pune', method: 'OTP', success: true, flagged: true),
  _LoginEvent(ts: DateTime(2026, 5, 16, 8, 45), device: 'iPad Air',
      city: 'Pune', method: 'OTP', success: true, flagged: true),
  _LoginEvent(ts: DateTime(2026, 5, 8, 9, 15), device: 'iPad Air',
      city: 'Pune', method: 'Biometric', success: true),
  _LoginEvent(ts: DateTime(2026, 5, 5, 14, 20), device: 'Unknown',
      city: 'Hyderabad', method: 'OTP (failed ×2)', success: false, flagged: true),
  _LoginEvent(ts: DateTime(2026, 4, 29, 10, 0), device: 'Samsung Galaxy S24',
      city: 'Mumbai', method: 'Biometric', success: true),
  _LoginEvent(ts: DateTime(2026, 4, 5, 11, 20), device: 'Samsung Galaxy S24',
      city: 'Mumbai', method: 'OTP', success: true),
  _LoginEvent(ts: DateTime(2026, 3, 15, 9, 0), device: 'Pixel 7',
      city: 'Mumbai', method: 'OTP', success: true),
];

// ── Mock service ───────────────────────────────────────────────────────────────
class _SessionService {
  static Future<void> revokeSession(String sessionId) =>
      Future.delayed(const Duration(milliseconds: 900));

  static Future<void> revokeAllOtherSessions() =>
      Future.delayed(const Duration(milliseconds: 1400));
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day179ActiveSessionsScreen extends ConsumerWidget {
  const Day179ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d179TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Active Sessions & Devices'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
            ),
            child: const Text('DAY 179',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10,
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
                onSelect: (t) => ref.read(_d179TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _SessionsTab(),
            if (tab == 1) const _LoginHistoryTab(),
            if (tab == 2) const _ApiContractTab(),
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
        gradient: const LinearGradient(
            colors: [Color(0xFF080E14), Color(0xFF050A10), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 179',             const Color(0xFF3B82F6)),
          _badge('🟡 MOCK-NOW',             const Color(0xFFF59E0B)),
          _badge('Section B  ·  Final block', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Active Sessions\n& Devices',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '4 active device sessions. Suspicious iPad flagged. '
          'Remote sign-out per session + sign-out-all. '
          'Login history with geographic anomaly detection. '
          'JWT management API contract.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('4',   '4 sessions',       Color(0xFF3B82F6)),
          _HStat('1',   'Suspicious',       Color(0xFFEF4444)),
          _HStat('8',   'Login events',     Color(0xFF8B5CF6)),
          _HStat('2',   'Flagged logins',   Color(0xFFF59E0B)),
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
      (Icons.devices_rounded,    Color(0xFF3B82F6), 'Sessions'),
      (Icons.login_rounded,      Color(0xFF8B5CF6), 'Login History'),
      (Icons.code_rounded,       Color(0xFFF59E0B), 'API Contract'),
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
// TAB 1 — Sessions
// ══════════════════════════════════════════════════════════════════════════════
class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions     = ref.watch(_activeSessionsProvider);
    final expanded     = ref.watch(_expandedSessionProvider);
    final signOutStates= ref.watch(_signOutStateProvider);
    final bulkState    = ref.watch(_signOutAllStateProvider);
    final bulkConfirm  = ref.watch(_signOutAllConfirmProvider);

    final suspiciousCount = sessions.where((s) => s.suspicious && !_isRevoked(s.id, sessions)).length;
    final otherCount      = sessions.where((s) => !s.isCurrent).length;
    final revokedCount    = signOutStates.values.where((s) => s == _SignOutState.done).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.devices_rounded, color: const Color(0xFF3B82F6),
          text: 'All devices where your ZapSafe account is signed in. '
              'Each session has its own JWT. Tap any session to expand. '
              'Sign out remotely to invalidate the JWT on that device.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats strip
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _stat('${sessions.length}', 'Total\nsessions',   const Color(0xFF3B82F6)),
          _stat('1',                  'Current\ndevice',   const Color(0xFF10B981)),
          _stat('$suspiciousCount',   'Suspicious',        const Color(0xFFEF4444)),
          _stat('$revokedCount',      'Signed out\n(demo)',const Color(0xFF6B7280)),
        ]),
      ),

      // Suspicious alert banner
      if (suspiciousCount > 0) ...[
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5))),
          child: const Row(children: [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 18),
            SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⚠️ Suspicious session detected',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text('iPad Air — unrecognised device with 3 failed vault PIN attempts.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            ])),
          ])),
      ],
      const SizedBox(height: ZapSpacing.lg),

      // Session cards
      const _SectionLabel('4 ACTIVE SESSIONS  ·  TAP TO MANAGE'),
      const SizedBox(height: ZapSpacing.md),

      ...sessions.map((session) {
        final soState  = signOutStates[session.id] ?? _SignOutState.idle;
        final isRevoked= soState == _SignOutState.done;
        final isExp    = expanded == session.id;
        final color    = session.suspicious ? const Color(0xFFEF4444)
            : session.isCurrent ? const Color(0xFF10B981)
            : const Color(0xFF3B82F6);

        return GestureDetector(
          onTap: isRevoked ? null : () {
            ref.read(_expandedSessionProvider.notifier).state =
                isExp ? null : session.id;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isRevoked ? const Color(0xFF141414)
                    : isExp ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isRevoked ? const Color(0xFF1A1A1A)
                        : isExp ? color.withOpacity(0.45) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  // Device icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: (isRevoked ? const Color(0xFF2A2A2A) : color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                        session.deviceType == 'iOS'
                            ? Icons.apple_rounded : Icons.android_rounded,
                        color: isRevoked ? const Color(0xFF3A3A3A) : color,
                        size: 20)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(session.deviceName,
                          style: TextStyle(
                              color: isRevoked ? const Color(0xFF4B5563) : Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w700))),
                      if (session.isCurrent)
                        _tag('CURRENT', const Color(0xFF10B981))
                      else if (session.suspicious && !isRevoked)
                        _tag('⚠ SUSPICIOUS', const Color(0xFFEF4444))
                      else if (isRevoked)
                        _tag('SIGNED OUT', const Color(0xFF4B5563)),
                    ]),
                    Text('${session.city}, ${session.country}  ·  ${session.os}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                    Text('Last active: ${_fmtRelative(session.lastActiveAt)}',
                        style: TextStyle(
                            color: isRevoked ? const Color(0xFF3A3A3A) : const Color(0xFF4B5563),
                            fontSize: 10)),
                  ])),
                  if (!isRevoked)
                    Icon(isExp ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              // Expanded detail
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: (isExp && !isRevoked)
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _SessionDetail(
                            session: session, soState: soState,
                            color: color, ref: ref))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.xl),

      // Sign out all other sessions
      const _SectionLabel('BULK ACTION'),
      const SizedBox(height: ZapSpacing.md),

      if (bulkState == _BulkState.idle && !bulkConfirm)
        _outlineBtn(
          label: 'Sign out all other sessions (${otherCount - revokedCount})',
          color: const Color(0xFFEF4444),
          onTap: () => ref.read(_signOutAllConfirmProvider.notifier).state = true,
        )
      else if (bulkState == _BulkState.idle && bulkConfirm)
        _BulkConfirmCard(ref: ref, otherCount: otherCount - revokedCount)
      else if (bulkState == _BulkState.signing)
        _statusCard(Icons.hourglass_top_rounded, const Color(0xFFEF4444),
            'Signing out all other sessions…',
            'DELETE /api/v1/account/sessions/all\n'
            'Invalidating ${otherCount - revokedCount} JWTs server-side.',
            loading: true)
      else
        _statusCard(Icons.check_circle_rounded, const Color(0xFF10B981),
            'All other sessions signed out ✅',
            '${otherCount} devices have been signed out. '
            'Their JWTs are now invalid.',
            loading: false),
    ]);
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3),
        textAlign: TextAlign.center),
  ]));

  static Widget _tag(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w800)));

  static String _fmtRelative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 30)     return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).round()}mo ago';
  }

  static bool _isRevoked(String id, List<_Session> sessions) => false; // simplified
}

class _SessionDetail extends StatelessWidget {
  final _Session session; final _SignOutState soState;
  final Color color; final WidgetRef ref;
  const _SessionDetail({required this.session, required this.soState,
      required this.color, required this.ref});

  @override
  Widget build(BuildContext context) {
    final dur = session.lastActiveAt.difference(session.startedAt);
    final durLabel = dur.inDays > 0 ? '${dur.inDays}d active' : '${dur.inHours}h active';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Suspicious warning
      if (session.suspicious) ...[
        Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 13),
            const SizedBox(width: 6),
            Expanded(child: Text(session.suspiciousReason ?? '',
                style: const TextStyle(color: Color(0xFFEF4444),
                    fontSize: 10, height: 1.4))),
          ])),
      ],
      // Metadata
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _kv('Session ID',   session.id),
          _kv('Device',       session.deviceName),
          _kv('OS',           session.os),
          _kv('App version',  session.appVersion),
          _kv('Location',     '${session.city}, ${session.country}  (IP redacted)'),
          _kv('Started',      _fmtFull(session.startedAt)),
          _kv('Last active',  _fmtFull(session.lastActiveAt)),
          _kv('Duration',     durLabel),
        ])),
      const SizedBox(height: ZapSpacing.md),

      // Sign-out button
      if (session.isCurrent)
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
          child: const Text('This is your current session. '
              'Sign out from Settings → Account instead.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, height: 1.4)))
      else if (soState == _SignOutState.idle)
        GestureDetector(
          onTap: () => _doSignOut(context, ref, session.id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 14),
              SizedBox(width: 6),
              Text('Sign out this session',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ])))
      else if (soState == _SignOutState.signing)
        _statusCard(Icons.hourglass_top_rounded, const Color(0xFFEF4444),
            'Signing out…',
            'DELETE /api/v1/account/sessions/${session.id}',
            loading: true)
      else
        _statusCard(Icons.check_circle_rounded, const Color(0xFF10B981),
            'Signed out ✅',
            'JWT invalidated. Device will see "Session expired" on next API call.',
            loading: false),
    ]);
  }

  Future<void> _doSignOut(BuildContext context, WidgetRef ref, String id) async {
    final map = Map<String, _SignOutState>.from(ref.read(_signOutStateProvider));
    map[id] = _SignOutState.signing;
    ref.read(_signOutStateProvider.notifier).state = map;

    await _SessionService.revokeSession(id);

    if (!context.mounted) return;
    final map2 = Map<String, _SignOutState>.from(ref.read(_signOutStateProvider));
    map2[id] = _SignOutState.done;
    ref.read(_signOutStateProvider.notifier).state = map2;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Session revoked ✅'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2)));
  }

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 84, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10,
            fontFamily: 'monospace', height: 1.4))),
      ]));

  static String _fmtFull(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:'
        '${d.minute.toString().padLeft(2,'0')}';
  }
}

class _BulkConfirmCard extends StatelessWidget {
  final WidgetRef ref; final int otherCount;
  const _BulkConfirmCard({required this.ref, required this.otherCount});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sign out all other sessions?',
            style: TextStyle(color: Color(0xFFEF4444), fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('This will sign out $otherCount other devices. '
            'Your current session remains active.',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4)),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(child: _outlineBtn(
            label: 'Cancel',
            color: const Color(0xFF6B7280),
            onTap: () => ref.read(_signOutAllConfirmProvider.notifier).state = false,
          )),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: GestureDetector(
            onTap: () async {
              ref.read(_signOutAllStateProvider.notifier).state = _BulkState.signing;
              ref.read(_signOutAllConfirmProvider.notifier).state = false;
              await _SessionService.revokeAllOtherSessions();
              ref.read(_signOutAllStateProvider.notifier).state = _BulkState.done;
              // Mark all non-current as done
              final map = <String, _SignOutState>{};
              for (final s in _kSessions) {
                if (!s.isCurrent) map[s.id] = _SignOutState.done;
              }
              ref.read(_signOutStateProvider.notifier).state = map;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5))),
              child: const Center(child: Text('Sign Out All',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12,
                      fontWeight: FontWeight.w700)))))),
        ]),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Login History
// ══════════════════════════════════════════════════════════════════════════════
class _LoginHistoryTab extends ConsumerWidget {
  const _LoginHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedLoginProvider);

    final flaggedCount  = _kLoginHistory.where((e) => e.flagged).length;
    final failedCount   = _kLoginHistory.where((e) => !e.success).length;
    final successCount  = _kLoginHistory.where((e) => e.success).length;

    // Geographic anomaly: all flagged logins from outside Mumbai
    final anomalyCount  = _kLoginHistory.where((e) => e.flagged && e.city != 'Mumbai').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.login_rounded, color: const Color(0xFF8B5CF6),
          text: 'Complete history of every sign-in and sign-in attempt. '
              'Flagged entries come from unrecognised devices or locations. '
              'Geographic anomaly detection highlights out-of-pattern logins.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _stat('${_kLoginHistory.length}', 'Total\nevents',   const Color(0xFF8B5CF6)),
          _stat('$successCount',            'Successful',      const Color(0xFF10B981)),
          _stat('$failedCount',             'Failed',          const Color(0xFFEF4444)),
          _stat('$flaggedCount',            '⚠ Flagged',       const Color(0xFFF59E0B)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Geographic anomaly card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.travel_explore_rounded, color: Color(0xFFF59E0B), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('Geographic Anomaly Detection',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Text('Your primary city: Mumbai, India\n'
              '$anomalyCount sign-in${anomalyCount == 1 ? "" : "s"} detected from outside your primary city:\n'
              '• Pune, India — iPad Air (May 8, 16, 25)\n'
              '• Hyderabad, India — Unknown device (May 5, failed)\n\n'
              'If these weren\'t you, sign out those sessions and change your account security settings.',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.6)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('8 LOGIN EVENTS  ·  NEWEST FIRST  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kLoginHistory.asMap().entries.map((e) {
        final i    = e.key;
        final evt  = e.value;
        final isExp= expanded == i;
        final color= evt.flagged
            ? const Color(0xFFF59E0B)
            : evt.success
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444);
        final icon = evt.flagged
            ? Icons.warning_rounded
            : evt.success
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded;

        return GestureDetector(
          onTap: () => ref.read(_expandedLoginProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
                color: isExp ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
                child: Row(children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(evt.device,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.w600))),
                      Text(_fmtShort(evt.ts),
                          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
                    ]),
                    Text('${evt.city}  ·  ${evt.method}',
                        style: TextStyle(color: color, fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ])),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _LoginDetail(evt: evt, color: color))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3),
        textAlign: TextAlign.center),
  ]));

  static String _fmtShort(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
}

class _LoginDetail extends StatelessWidget {
  final _LoginEvent evt; final Color color;
  const _LoginDetail({required this.evt, required this.color});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (evt.flagged) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.07),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3))),
            child: Text(
              evt.success
                  ? '⚠ Flagged: sign-in from outside your primary city (Mumbai). '
                    'If this wasn\'t you, sign out the session above.'
                  : '🔴 Failed sign-in attempt. If this wasn\'t you, your account '
                    'may be targeted. Consider enabling additional security.',
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, height: 1.4))),
        ],
        _kvRow('Device',  evt.device),
        _kvRow('Location','${evt.city}  (IP redacted per DPDP §11)'),
        _kvRow('Method',  evt.method),
        _kvRow('Result',  evt.success ? 'Success ✅' : 'Failed ❌'),
        _kvRow('Time',    _fmtFull(evt.ts)),
      ]));

  Widget _kvRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(width: 72, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10))),
      ]));

  static String _fmtFull(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:'
        '${d.minute.toString().padLeft(2,'0')} IST';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — API Contract
// ══════════════════════════════════════════════════════════════════════════════
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(icon: Icons.code_rounded, color: const Color(0xFFF59E0B),
        text: 'Backend at Day 78. No /account/sessions API exists yet. '
            'Document here for zero-conflict implementation. '
            'Day 174 Sessions tab uses the same contract.'),
    const SizedBox(height: ZapSpacing.lg),

    const _SectionLabel('ENDPOINT 1 — LIST ACTIVE SESSIONS'),
    const SizedBox(height: ZapSpacing.md),
    _code(context, '''// GET /api/v1/account/sessions
// Auth: Bearer JWT required
// Returns all sessions with active (non-expired, non-revoked) JWTs

// RESPONSE 200 OK
{
  "sessions": [
    {
      "session_id": "sess_s24_current",
      "device_name": "Samsung Galaxy S24",
      "device_type": "Android",          // "Android" | "iOS" | "Web"
      "os": "Android 14 (API 34)",
      "app_version": "v1.0.0 (build 150)",
      "city": "Mumbai",
      "country": "India",
      // IP address NOT returned — DPDP §11 city-level only
      "started_at": "2026-05-28T10:12:00Z",
      "last_active_at": "2026-05-30T14:30:00Z",
      "is_current": true,
      "suspicious": false,
      "suspicious_reason": null
    }
  ],
  "suspicious_count": 1,
  "total": 4
}'''),

    const SizedBox(height: ZapSpacing.lg),
    const _SectionLabel('ENDPOINT 2 — REVOKE SINGLE SESSION'),
    const SizedBox(height: ZapSpacing.md),
    _code(context, '''// DELETE /api/v1/account/sessions/{session_id}
// Auth: Bearer JWT required
// Cannot revoke current session via this endpoint

// RESPONSE 200 OK
{
  "session_id": "sess_ipad_suspicious",
  "revoked": true,
  "message": "Session revoked. Device will receive 401 on next API call."
}

// RESPONSE 400 — attempt to revoke current session
{
  "error": "cannot_revoke_current",
  "message": "Sign out from the app Settings to end your current session."
}

// RESPONSE 404 — session already expired/revoked
{
  "error": "session_not_found"
}'''),

    const SizedBox(height: ZapSpacing.lg),
    const _SectionLabel('ENDPOINT 3 — REVOKE ALL OTHER SESSIONS'),
    const SizedBox(height: ZapSpacing.md),
    _code(context, '''// DELETE /api/v1/account/sessions/all
// Auth: Bearer JWT required
// Revokes all sessions EXCEPT the one making this request

// RESPONSE 200 OK
{
  "revoked_count": 3,
  "kept_session": "sess_s24_current",
  "message": "3 sessions revoked. All other devices will see 401."
}'''),

    const SizedBox(height: ZapSpacing.lg),
    const _SectionLabel('ENDPOINT 4 — LOGIN HISTORY'),
    const SizedBox(height: ZapSpacing.md),
    _code(context, '''// GET /api/v1/account/login-history
// Auth: Bearer JWT required
// Returns recent authentication events

// RESPONSE 200 OK
{
  "events": [
    {
      "id": "login_001",
      "timestamp": "2026-05-28T10:12:00Z",
      "device": "Samsung Galaxy S24",
      "city": "Mumbai",
      "country": "India",
      // IP NOT returned (DPDP §11)
      "method": "OTP",                  // "OTP" | "Biometric" | "Failed"
      "success": true,
      "flagged": false,
      "flagged_reason": null
    }
  ],
  "flagged_count": 3,
  "total": 8
}'''),

    const SizedBox(height: ZapSpacing.lg),
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
        text: 'Day 180 adds: trusted devices, session expiry configuration, '
            'automatic suspicious-session alerts via push notification, '
            'and the Section B (Days 166-180) complete sign-off.'),
  ]);
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _code(BuildContext context, String code) => GestureDetector(
    onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 1))),
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

Widget _outlineBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)))));

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

// fix missing fromLTRB
extension _EdgeInsets on Padding {
  // ignore — used directly in code above
}

// ── Fix the Padding.fromLTRB typo in _SessionDetail ───────────────────────────
// Dart uses fromLTRB not fromLTRB — corrected inline above.
