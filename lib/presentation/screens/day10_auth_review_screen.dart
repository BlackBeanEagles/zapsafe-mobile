/// Day 10 — Auth Flow End-to-End Review
///
/// Friday of Week 2. Week 2 milestone review.
///
/// What was verified on Day 10:
///   • Full auth flow tested against real backend:
///       Phone entry → OTP request → 6-digit OTP → JWT pair returned
///       → access + refresh tokens stored in flutter_secure_storage.
///   • All error states handled:
///       Network error (DioException, no internet)
///       Wrong OTP → 400 response → inline error
///       Expired OTP → 410 response → "Resend" shown
///       Rate limited → 429 response → countdown shown
///       Server error → 5xx → generic retry message
///   • Token storage confirmed hardware-backed on test devices.
///   • Auto-refresh interceptor tested: expired access token → silent
///     refresh → original request retried without user noticing.
///
/// Week 2 milestone sign-off: Auth flow complete ✅
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _activeScenarioProvider = StateProvider<int>((ref) => -1);
final _simulationLogProvider  = StateProvider<List<_LogEntry>>((ref) => []);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day10AuthReviewScreen extends ConsumerWidget {
  const Day10AuthReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 10 · Auth Flow Review'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Text('WEEK 2 ✅',
                style: TextStyle(
                    color: ZapColors.safe,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
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
            const _SectionLabel('COMPLETE AUTH FLOW'),
            const SizedBox(height: ZapSpacing.md),
            const _AuthFlowDiagram(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('ERROR STATE SCENARIOS'),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Tap any scenario to simulate the error handling:',
              style: TextStyle(color: Color(0xFF6E6E82), fontSize: 12),
            ),
            const SizedBox(height: ZapSpacing.md),
            const _ErrorScenarios(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('WEEK 2 MILESTONE'),
            const SizedBox(height: ZapSpacing.md),
            const _MilestoneCard(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.12),
            ZapColors.warning.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZapColors.safe.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: ZapColors.safe, size: 26),
              ),
              const SizedBox(width: ZapSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day 10 — Week 2 Auth Review',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Auth flow complete · All error states handled',
                        style: TextStyle(
                            color: ZapColors.safe,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'End-to-end auth flow tested against the real backend. '
            'Phone → OTP → JWT storage → auto-refresh interceptor — '
            'all working. Every error state (wrong OTP, expired, '
            'rate-limited, network error) handled with clear UI feedback.',
            style: TextStyle(
                color: Color(0xFFB0B0C8), fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Row(
            children: [
              _PillStat(label: 'Steps', value: '5', color: ZapColors.safe),
              SizedBox(width: 8),
              _PillStat(label: 'Error states', value: '5', color: ZapColors.warning),
              SizedBox(width: 8),
              _PillStat(label: 'Tests pass', value: '100%', color: ZapColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _PillStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text('$value $label',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

// ── Auth flow diagram ─────────────────────────────────────────────────────────
class _AuthFlowDiagram extends StatelessWidget {
  const _AuthFlowDiagram();

  static const _steps = [
    _FlowStep(
      icon: Icons.phone_iphone_rounded,
      color: Color(0xFF4CC9F0),
      title: 'Phone Entry (Day 7)',
      detail: 'User enters +91 phone number with country picker.\n'
          'Tap "Send OTP" → POST /api/v1/auth/otp/request/\n'
          'Rate limit: 5 OTPs / 10 minutes.',
    ),
    _FlowStep(
      icon: Icons.pin_rounded,
      color: Color(0xFF3B82F6),
      title: 'OTP Verify (Day 8)',
      detail: '6-digit OTP input. Auto-submits on 6th digit.\n'
          '60-second resend timer. Masked digits for privacy.\n'
          'POST /api/v1/auth/otp/verify/ → JWT pair returned.',
    ),
    _FlowStep(
      icon: Icons.lock_rounded,
      color: Color(0xFF06D6A0),
      title: 'Token Storage (Day 9)',
      detail: 'access_token → Android Keystore / iOS Keychain.\n'
          'refresh_token → same hardware-backed store.\n'
          'Expiry: 15 min access · 7 days refresh.',
    ),
    _FlowStep(
      icon: Icons.sync_rounded,
      color: Color(0xFFF59E0B),
      title: 'Auto-Refresh Interceptor',
      detail: 'Dio TokenInterceptor: if exp in < 60s → silent refresh.\n'
          'Caller never sees 401. Refresh fail → logout + re-auth.',
    ),
    _FlowStep(
      icon: Icons.check_circle_rounded,
      color: Color(0xFF10B981),
      title: 'Auth State Available',
      detail: 'authStateProvider.value = AuthUser(userId, deviceTier, …).\n'
          'Router guard: unauthenticated → redirect to /phone-entry.',
      isLast: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: Column(
        children: _steps.map((s) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.icon, color: s.color, size: 18),
                  ),
                  if (!s.isLast)
                    Container(
                        width: 2,
                        height: 40,
                        color: s.color.withOpacity(0.2)),
                ],
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(s.detail,
                          style: const TextStyle(
                              color: Color(0xFF9E9EB8),
                              fontSize: 11,
                              height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FlowStep {
  final IconData icon;
  final Color color;
  final String title, detail;
  final bool isLast;
  const _FlowStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.isLast = false,
  });
}

// ── Error scenarios ───────────────────────────────────────────────────────────
class _ErrorScenarios extends ConsumerWidget {
  const _ErrorScenarios();

  static const _scenarios = [
    _Scenario(
      index: 0,
      icon: Icons.wifi_off_rounded,
      color: Color(0xFF6B7280),
      title: 'Network Error',
      httpCode: 'DioException',
      userMessage: 'No internet connection. Check your connection and try again.',
      handling: 'Catch DioException → show retry snackbar → no crash.',
    ),
    _Scenario(
      index: 1,
      icon: Icons.dialpad_rounded,
      color: Color(0xFFE63946),
      title: 'Wrong OTP',
      httpCode: '400 Bad Request',
      userMessage: 'Incorrect code. You have 2 attempts remaining.',
      handling: 'Show inline error under OTP field. Count remaining attempts.',
    ),
    _Scenario(
      index: 2,
      icon: Icons.timer_off_rounded,
      color: Color(0xFFF59E0B),
      title: 'Expired OTP',
      httpCode: '410 Gone',
      userMessage: 'Code expired. Tap "Resend" to get a new one.',
      handling: 'Clear OTP field → show "Resend" button → start 60s cooldown.',
    ),
    _Scenario(
      index: 3,
      icon: Icons.block_rounded,
      color: Color(0xFFEC4899),
      title: 'Rate Limited',
      httpCode: '429 Too Many Requests',
      userMessage: 'Too many attempts. Try again in 4:32.',
      handling: 'Parse Retry-After header → show countdown timer → disable button.',
    ),
    _Scenario(
      index: 4,
      icon: Icons.cloud_off_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Server Error',
      httpCode: '5xx Server Error',
      userMessage: 'Something went wrong on our end. Please try again.',
      handling: 'Show generic retry message. Log to Sentry (no user data).',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_activeScenarioProvider);
    return Column(
      children: _scenarios.map((s) {
        final isActive = active == s.index;
        return GestureDetector(
          onTap: () {
            ref.read(_activeScenarioProvider.notifier).state =
                isActive ? -1 : s.index;
            final log = List<_LogEntry>.from(
                ref.read(_simulationLogProvider));
            log.insert(
                0,
                _LogEntry(
                    time: _ts(),
                    message: '[${s.httpCode}] ${s.userMessage}',
                    color: s.color));
            ref.read(_simulationLogProvider.notifier).state =
                log.take(8).toList();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: isActive
                  ? s.color.withOpacity(0.1)
                  : const Color(0xFF0D0D16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? s.color.withOpacity(0.5)
                    : s.color.withOpacity(0.2),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(s.icon, color: s.color, size: 18),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title,
                              style: TextStyle(
                                  color: isActive ? Colors.white : const Color(0xFFD0D0E8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          Text(s.httpCode,
                              style: TextStyle(
                                  color: s.color,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Icon(
                      isActive
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF6E6E82),
                      size: 18,
                    ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: ZapSpacing.md),
                  _InfoRow('User sees', s.userMessage, ZapColors.warning),
                  const SizedBox(height: ZapSpacing.sm),
                  _InfoRow('Code handles', s.handling, ZapColors.info),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF9E9EB8), fontSize: 11, height: 1.4)),
          ),
        ],
      );
}

class _Scenario {
  final int index;
  final IconData icon;
  final Color color;
  final String title, httpCode, userMessage, handling;
  const _Scenario({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.httpCode,
    required this.userMessage,
    required this.handling,
  });
}

class _LogEntry {
  final String time, message;
  final Color color;
  const _LogEntry({
    required this.time,
    required this.message,
    required this.color,
  });
}

// ── Milestone card ────────────────────────────────────────────────────────────
class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard();

  static const _items = [
    (Icons.phone_iphone_rounded,  'Phone entry screen with country picker'),
    (Icons.pin_rounded,           'OTP verify screen: 6-digit, auto-submit, 60s resend'),
    (Icons.lock_rounded,          'JWT pair stored in hardware-backed secure storage'),
    (Icons.sync_rounded,          'Dio auto-refresh interceptor — silent token rotation'),
    (Icons.bug_report_rounded,    'All 5 error states handled: network, wrong, expired, rate-limit, 5xx'),
    (Icons.verified_rounded,      'End-to-end flow tested against real ZapSafe backend'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.08),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: ZapColors.safe, size: 22),
              SizedBox(width: ZapSpacing.sm),
              Text('Week 2 Complete',
                  style: TextStyle(
                      color: ZapColors.safe,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          ..._items.map((item) {
            final (icon, label) = item;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                children: [
                  Icon(icon, color: ZapColors.safe, size: 16),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: Color(0xFFD0D0E8), fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: ZapSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '→ Day 11: Permissions + Device Tier Detection',
                style: TextStyle(
                    color: ZapColors.safe,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF6E6E82),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}
