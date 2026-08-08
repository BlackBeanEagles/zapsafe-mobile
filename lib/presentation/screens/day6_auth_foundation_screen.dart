import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_config.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/auth_models.dart';
import '../../domain/providers/auth_providers.dart';
import '../../domain/state/auth_state.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';
import '../widgets/zap_text_field.dart';

/// Day 6 — Auth foundation
///
/// Wires the live backend together end-to-end. Three demos on one screen:
/// 1. Backend reachability — `service.ping()` shows ✅ / ❌.
/// 2. Live OTP request — type a phone, hit "Send OTP", see the server response.
/// 3. Live verify — paste the 6-digit OTP, see JWT pair land in secure storage.
class Day6AuthFoundationScreen extends ConsumerStatefulWidget {
  const Day6AuthFoundationScreen({super.key});

  @override
  ConsumerState<Day6AuthFoundationScreen> createState() =>
      _Day6AuthFoundationScreenState();
}

class _Day6AuthFoundationScreenState
    extends ConsumerState<Day6AuthFoundationScreen> {
  final _phoneCtrl = TextEditingController(text: '+919876543210');
  final _otpCtrl = TextEditingController();

  bool _pinging = false;
  bool? _pingOk;
  String? _pingHint;

  bool _requesting = false;
  bool _verifying = false;
  OtpRequestResponse? _lastOtpResponse;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _ping() async {
    setState(() {
      _pinging = true;
      _pingOk = null;
      _pingHint = null;
    });
    final svc = ref.read(authServiceProvider);
    final ok = await svc.ping();
    if (!mounted) return;
    setState(() {
      _pinging = false;
      _pingOk = ok;
      _pingHint = ok ? 'Server is up.' : 'No response. Is the backend running on ${ApiConfig.baseUrl}?';
    });
  }

  Future<void> _requestOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ZapSnackbar.warning(context, 'Enter a phone number first.');
      return;
    }
    setState(() {
      _requesting = true;
      _lastOtpResponse = null;
    });
    final res = await ref.read(authStateProvider.notifier).requestOtp(phone);
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _lastOtpResponse = res;
    });
    if (res != null) {
      ZapSnackbar.success(context,
          'OTP sent to ${res.phone}. Expires in ${res.expiresIn}s.');
    } else {
      final s = ref.read(authStateProvider);
      if (s is AuthFailure) {
        ZapSnackbar.danger(context, s.message);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      ZapSnackbar.warning(context, 'OTP must be 6 digits.');
      return;
    }
    setState(() => _verifying = true);
    final ok = await ref.read(authStateProvider.notifier).verifyOtp(phone: phone, otp: otp);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (ok) {
      ZapSnackbar.success(context, 'Signed in. JWT pair stored.');
      _otpCtrl.clear();
    } else {
      final s = ref.read(authStateProvider);
      if (s is AuthFailure) {
        ZapSnackbar.danger(context, s.message);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    ZapSnackbar.info(context, 'Logged out. Tokens wiped from secure storage.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 6 · Auth Foundation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: ZapSpacing.xxxl),

              // ─── Section 1: backend reachability ────────────────────
              const _SectionTitle('1 · BACKEND REACHABILITY'),
              const SizedBox(height: ZapSpacing.md),
              _BackendCard(
                baseUrl: ApiConfig.baseUrl,
                pinging: _pinging,
                pingOk: _pingOk,
                hint: _pingHint,
                onPing: _ping,
              ),
              const SizedBox(height: ZapSpacing.xxxl),

              // ─── Section 2: request OTP ─────────────────────────────
              const _SectionTitle('2 · POST /auth/register/'),
              const SizedBox(height: ZapSpacing.md),
              ZapCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ZapTextField(
                      label: 'Phone (E.164)',
                      hint: '+919876543210',
                      prefixIcon: Icons.phone_rounded,
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      helperText: 'Backend rejects anything not in E.164 format.',
                    ),
                    const SizedBox(height: ZapSpacing.lg),
                    ZapButton.elevated(
                      label: _requesting ? '' : 'SEND OTP',
                      icon: Icons.send_rounded,
                      intent: ZapButtonIntent.info,
                      fullWidth: true,
                      isLoading: _requesting,
                      onPressed: _requesting ? null : _requestOtp,
                    ),
                    if (_lastOtpResponse != null) ...[
                      const SizedBox(height: ZapSpacing.md),
                      _ResponseBlock(
                        title: '200 OK',
                        accent: ZapColors.safe,
                        lines: [
                          'phone:       ${_lastOtpResponse!.phone}',
                          'expires_in:  ${_lastOtpResponse!.expiresIn}s',
                          'message:     ${_lastOtpResponse!.message}',
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xxxl),

              // ─── Section 3: verify OTP ──────────────────────────────
              const _SectionTitle('3 · POST /auth/verify-otp/'),
              const SizedBox(height: ZapSpacing.md),
              ZapCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ZapTextField(
                      label: 'OTP (6 digits)',
                      hint: '123456',
                      prefixIcon: Icons.password_rounded,
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      helperText: 'Check your SMS, or the backend logs in dev mode.',
                    ),
                    const SizedBox(height: ZapSpacing.lg),
                    ZapButton.elevated(
                      label: _verifying ? '' : 'VERIFY & SIGN IN',
                      icon: Icons.verified_rounded,
                      intent: ZapButtonIntent.safe,
                      fullWidth: true,
                      isLoading: _verifying,
                      onPressed: _verifying ? null : _verifyOtp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xxxl),

              // ─── Section 4: session state ───────────────────────────
              const _SectionTitle('4 · SESSION STATE'),
              const SizedBox(height: ZapSpacing.md),
              _SessionCard(state: auth, onLogout: _logout),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: ZapColors.info.withOpacity(0.08),
      borderColor: ZapColors.info.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.api_rounded, color: ZapColors.info, size: 24),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 2 · DAY 6', intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Auth Foundation',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Models • Dio client (auth + refresh + logging interceptors) • Secure token storage • AuthService — all wired to the real Django backend.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}

class _BackendCard extends StatelessWidget {
  final String baseUrl;
  final bool pinging;
  final bool? pingOk;
  final String? hint;
  final VoidCallback onPing;

  const _BackendCard({
    required this.baseUrl,
    required this.pinging,
    required this.pingOk,
    required this.hint,
    required this.onPing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pingOk == null
        ? ZapColors.info
        : pingOk!
            ? ZapColors.safe
            : ZapColors.danger;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.public_rounded, color: accent, size: 22),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  baseUrl,
                  style: ZapTypography.monoLarge.copyWith(color: ZapColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pingOk != null)
                ZapBadge(
                  label: pingOk! ? 'REACHABLE' : 'UNREACHABLE',
                  intent: pingOk! ? ZapBadgeIntent.safe : ZapBadgeIntent.danger,
                  icon: pingOk! ? Icons.check_circle : Icons.error,
                  size: ZapBadgeSize.small,
                ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text(
              hint!,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
            ),
          ],
          const SizedBox(height: ZapSpacing.md),
          ZapButton.tonal(
            label: pinging ? '' : 'PING /docs/',
            icon: Icons.network_check_rounded,
            intent: ZapButtonIntent.info,
            fullWidth: true,
            isLoading: pinging,
            onPressed: pinging ? null : onPing,
          ),
        ],
      ),
    );
  }
}

class _ResponseBlock extends StatelessWidget {
  final String title;
  final List<String> lines;
  final Color accent;

  const _ResponseBlock({required this.title, required this.lines, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: accent.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ZapTypography.labelSmall.copyWith(
              color: accent,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  l,
                  style: ZapTypography.monoSmall.copyWith(color: ZapColors.textPrimary),
                ),
              )),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AuthState state;
  final VoidCallback onLogout;

  const _SessionCard({required this.state, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AuthInitial() || AuthLoading() => const _StatusRow(
          color: ZapColors.textSecondary,
          icon: Icons.hourglass_top_rounded,
          title: 'Loading…',
          subtitle: 'Reading secure storage.',
        ),
      AuthUnauthenticated() => _StatusRow(
          color: ZapColors.textSecondary,
          icon: Icons.no_accounts_rounded,
          title: 'Not signed in',
          subtitle: 'No JWT tokens in secure storage.',
          trailing: (state as AuthUnauthenticated).message == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: ZapSpacing.sm),
                  child: Text(
                    (state as AuthUnauthenticated).message!,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.info,
                    ),
                  ),
                ),
        ),
      AuthAuthenticated() => _SessionDetails(
          tokens: (state as AuthAuthenticated).tokens,
          onLogout: onLogout,
        ),
      AuthFailure() => _StatusRow(
          color: ZapColors.danger,
          icon: Icons.error_rounded,
          title: (state as AuthFailure).code ?? 'Error',
          subtitle: (state as AuthFailure).message,
        ),
    };
  }
}

class _StatusRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _StatusRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: ZapTypography.headlineSmall
                            .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SessionDetails extends StatelessWidget {
  final AuthTokens tokens;
  final VoidCallback onLogout;
  const _SessionDetails({required this.tokens, required this.onLogout});

  String _trunc(String s, [int head = 16, int tail = 8]) {
    if (s.length <= head + tail + 3) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
  }

  @override
  Widget build(BuildContext context) {
    final u = tokens.user;
    return ZapCard(
      backgroundColor: ZapColors.safe.withOpacity(0.06),
      borderColor: ZapColors.safe.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: ZapColors.safe, size: 28),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Text(
                  'Signed in',
                  style: ZapTypography.headlineSmall.copyWith(
                    color: ZapColors.safe,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (tokens.isNewUser)
                const ZapBadge(
                  label: 'NEW USER',
                  intent: ZapBadgeIntent.info,
                  icon: Icons.celebration,
                  size: ZapBadgeSize.small,
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _kv('id', u.id),
          _kv('phone', u.phone),
          _kv('full_name', u.fullName ?? '∅'),
          _kv('device_tier', u.deviceTier ?? '∅'),
          _kv('is_onboarded', u.isOnboarded.toString()),
          const SizedBox(height: ZapSpacing.md),
          _kv('access', _trunc(tokens.access)),
          _kv('refresh', _trunc(tokens.refresh)),
          const SizedBox(height: ZapSpacing.md),
          ZapButton.outlined(
            label: 'LOG OUT',
            icon: Icons.logout_rounded,
            intent: ZapButtonIntent.danger,
            fullWidth: true,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
