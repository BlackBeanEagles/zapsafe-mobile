/// Day 9 — JWT Secure Token Storage
///
/// Thursday of Week 2.
///
/// What was built on Day 9:
///   • flutter_secure_storage wired for both platforms:
///       Android → Android Keystore (hardware-backed encryption)
///       iOS     → iOS Keychain (Secure Enclave where available)
///   • Two tokens stored:
///       'zapsafe_access_token'   — short-lived JWT (15 min)
///       'zapsafe_refresh_token'  — long-lived JWT (7 days)
///   • Dio interceptor (`TokenInterceptor`) added to all API calls:
///       1. Checks if access token is expired (exp claim).
///       2. If expired → silently calls POST /api/v1/auth/token/refresh/.
///       3. Retries the original request with new access token.
///       4. If refresh fails → clear storage → redirect to /phone-entry.
///   • NEVER store tokens in SharedPreferences (plain text on device).
///
/// LP requirement: all stored credentials must be hardware-backed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Mock state providers ──────────────────────────────────────────────────────
final _accessTokenProvider  = StateProvider<String?>((ref) => null);
final _refreshTokenProvider = StateProvider<String?>((ref) => null);
final _storageLogProvider   = StateProvider<List<String>>((ref) => []);
final _interceptorActiveProvider = StateProvider<bool>((ref) => true);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day9JwtStorageScreen extends ConsumerWidget {
  const Day9JwtStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 9 · JWT Secure Storage'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZapColors.info.withOpacity(0.4)),
            ),
            child: const Text('WEEK 2',
                style: TextStyle(
                    color: ZapColors.info,
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
            const _SectionLabel('STORAGE STRATEGY'),
            const SizedBox(height: ZapSpacing.md),
            const _StorageStrategyCard(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('TOKEN VAULT DEMO'),
            const SizedBox(height: ZapSpacing.md),
            const _TokenVaultDemo(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('DIO INTERCEPTOR — AUTO-REFRESH'),
            const SizedBox(height: ZapSpacing.md),
            const _InterceptorCard(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SECURITY RULES'),
            const SizedBox(height: ZapSpacing.md),
            const _SecurityRules(),
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
            ZapColors.info.withOpacity(0.12),
            ZapColors.safe.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZapColors.info.withOpacity(0.25)),
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
                  color: ZapColors.info.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: ZapColors.info, size: 26),
              ),
              const SizedBox(width: ZapSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day 9 — JWT Secure Storage',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Week 2 · Auth Infrastructure',
                        style: TextStyle(
                            color: ZapColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'JWT tokens are stored in platform-native hardware-backed '
            'secure storage — Android Keystore on Android, iOS Keychain on '
            'iPhone. A Dio interceptor silently refreshes the access token '
            'before any API call fails with 401.',
            style: TextStyle(
                color: Color(0xFFB0B0C8), fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              _Chip('flutter_secure_storage', ZapColors.info),
              const SizedBox(width: 8),
              _Chip('dio interceptor', ZapColors.safe),
              const SizedBox(width: 8),
              _Chip('LP-Keystore', ZapColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      );
}

// ── Storage strategy ──────────────────────────────────────────────────────────
class _StorageStrategyCard extends StatelessWidget {
  const _StorageStrategyCard();

  static const _rows = [
    _StorageRow(
      platform: 'Android',
      backend: 'Android Keystore',
      strength: 'Hardware-backed (TEE)',
      keyName: 'zapsafe_access_token',
      color: Color(0xFF3DDC84),
      icon: Icons.android_rounded,
    ),
    _StorageRow(
      platform: 'Android',
      backend: 'Android Keystore',
      strength: 'Hardware-backed (TEE)',
      keyName: 'zapsafe_refresh_token',
      color: Color(0xFF3DDC84),
      icon: Icons.android_rounded,
    ),
    _StorageRow(
      platform: 'iOS',
      backend: 'iOS Keychain',
      strength: 'Secure Enclave (A-series)',
      keyName: 'zapsafe_access_token',
      color: Color(0xFF9CA3AF),
      icon: Icons.phone_iphone_rounded,
    ),
    _StorageRow(
      platform: 'iOS',
      backend: 'iOS Keychain',
      strength: 'Secure Enclave (A-series)',
      keyName: 'zapsafe_refresh_token',
      color: Color(0xFF9CA3AF),
      icon: Icons.phone_iphone_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows
          .map((r) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: r.color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: r.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(r.icon, color: r.color, size: 18),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.keyName,
                              style: const TextStyle(
                                  color: Color(0xFFD0D0E8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace')),
                          const SizedBox(height: 2),
                          Text('${r.platform} · ${r.backend}',
                              style: TextStyle(
                                  color: r.color.withOpacity(0.8),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(r.strength,
                          style: TextStyle(
                              color: r.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _StorageRow {
  final String platform, backend, strength, keyName;
  final Color color;
  final IconData icon;
  const _StorageRow({
    required this.platform,
    required this.backend,
    required this.strength,
    required this.keyName,
    required this.color,
    required this.icon,
  });
}

// ── Token vault demo ──────────────────────────────────────────────────────────
class _TokenVaultDemo extends ConsumerWidget {
  const _TokenVaultDemo();

  static const _mockAccess =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyXzEyMyIsImV4cCI6MTcxMzQ4MDAwMH0.abc';
  static const _mockRefresh =
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyXzEyMyIsImV4cCI6MTcxNDA4MDAwMH0.xyz';

  void _store(WidgetRef ref) {
    ref.read(_accessTokenProvider.notifier).state = _mockAccess;
    ref.read(_refreshTokenProvider.notifier).state = _mockRefresh;
    final log = List<String>.from(ref.read(_storageLogProvider));
    log.add('✅ [${_ts()}] WRITE access_token → Android Keystore');
    log.add('✅ [${_ts()}] WRITE refresh_token → Android Keystore');
    ref.read(_storageLogProvider.notifier).state = log;
  }

  void _read(BuildContext context, WidgetRef ref) {
    final access = ref.read(_accessTokenProvider);
    final log = List<String>.from(ref.read(_storageLogProvider));
    if (access != null) {
      log.add('📖 [${_ts()}] READ access_token → ${access.substring(0, 20)}…');
      ref.read(_storageLogProvider.notifier).state = log;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token stored yet — store first')),
      );
    }
  }

  void _clear(WidgetRef ref) {
    ref.read(_accessTokenProvider.notifier).state = null;
    ref.read(_refreshTokenProvider.notifier).state = null;
    final log = List<String>.from(ref.read(_storageLogProvider));
    log.add('🗑  [${_ts()}] DELETE all tokens → storage cleared');
    ref.read(_storageLogProvider.notifier).state = log;
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access  = ref.watch(_accessTokenProvider);
    final refresh = ref.watch(_refreshTokenProvider);
    final log     = ref.watch(_storageLogProvider);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Token status
          _TokenRow('ACCESS TOKEN', access, const Duration(minutes: 15)),
          const SizedBox(height: ZapSpacing.sm),
          _TokenRow('REFRESH TOKEN', refresh, const Duration(days: 7)),
          const SizedBox(height: ZapSpacing.lg),
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZapColors.safe.withOpacity(0.2),
                    foregroundColor: ZapColors.safe,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _store(ref),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Store', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZapColors.info.withOpacity(0.2),
                    foregroundColor: ZapColors.info,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _read(context, ref),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('Read', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZapColors.danger.withOpacity(0.2),
                    foregroundColor: ZapColors.danger,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _clear(ref),
                  icon: const Icon(Icons.delete_rounded, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          if (log.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.lg),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF070710),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: log
                    .reversed
                    .take(5)
                    .map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(l,
                              style: const TextStyle(
                                  color: Color(0xFF9E9EB8),
                                  fontSize: 11,
                                  fontFamily: 'monospace')),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final String label;
  final String? token;
  final Duration expiry;
  const _TokenRow(this.label, this.token, this.expiry);

  @override
  Widget build(BuildContext context) {
    final hasToken = token != null;
    return Row(
      children: [
        Icon(
          hasToken ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: hasToken ? ZapColors.safe : const Color(0xFF3A3A4A),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF9E9EB8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              if (hasToken)
                Text(
                  '${token!.substring(0, 24)}…',
                  style: const TextStyle(
                      color: Color(0xFFD0D0E8),
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hasToken
                ? ZapColors.safe.withOpacity(0.1)
                : const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            hasToken ? 'STORED · ${_expiryLabel(expiry)}' : 'EMPTY',
            style: TextStyle(
                color: hasToken ? ZapColors.safe : const Color(0xFF4A4A5A),
                fontSize: 10,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  String _expiryLabel(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d expiry';
    return '${d.inMinutes}m expiry';
  }
}

// ── Interceptor card ──────────────────────────────────────────────────────────
class _InterceptorCard extends ConsumerWidget {
  const _InterceptorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_interceptorActiveProvider);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? ZapColors.safe.withOpacity(0.3)
              : const Color(0xFF2A2A3A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_rounded, color: ZapColors.info, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              const Expanded(
                child: Text('TokenInterceptor (Dio)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              Switch(
                value: active,
                onChanged: (v) =>
                    ref.read(_interceptorActiveProvider.notifier).state = v,
                activeColor: ZapColors.safe,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _FlowStep(
            step: '1',
            label: 'Intercept outgoing request',
            detail: 'Every API call passes through TokenInterceptor first.',
            active: active,
          ),
          _FlowStep(
            step: '2',
            label: 'Check access token exp claim',
            detail: 'Decode JWT payload → read exp → compare with now.',
            active: active,
          ),
          _FlowStep(
            step: '3',
            label: 'If expired → silent refresh',
            detail:
                'POST /api/v1/auth/token/refresh/ with stored refresh token.',
            active: active,
          ),
          _FlowStep(
            step: '4',
            label: 'Retry with new access token',
            detail: 'Original request retried — caller never sees the 401.',
            active: active,
          ),
          _FlowStep(
            step: '5',
            label: 'If refresh fails → logout',
            detail:
                'Clear both tokens → redirect to /phone-entry (forced re-auth).',
            active: active,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String step, label, detail;
  final bool active;
  final bool isLast;
  const _FlowStep({
    required this.step,
    required this.label,
    required this.detail,
    required this.active,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: active
                    ? ZapColors.info.withOpacity(0.2)
                    : const Color(0xFF1A1A24),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(step,
                    style: TextStyle(
                        color: active ? ZapColors.info : const Color(0xFF4A4A5A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            if (!isLast)
              Container(
                  width: 1,
                  height: 28,
                  color: active
                      ? ZapColors.info.withOpacity(0.2)
                      : const Color(0xFF1A1A24)),
          ],
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF4A4A5A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        color: active
                            ? const Color(0xFF9E9EB8)
                            : const Color(0xFF3A3A4A),
                        fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Security rules ────────────────────────────────────────────────────────────
class _SecurityRules extends StatelessWidget {
  const _SecurityRules();

  static const _rules = [
    (Icons.block_rounded, ZapColors.danger,
        'NEVER SharedPreferences',
        'SharedPreferences is plain text on disk. Any app with storage access can read it.'),
    (Icons.lock_rounded, ZapColors.safe,
        'Always flutter_secure_storage',
        'Uses Android Keystore + iOS Keychain. Hardware-backed on modern devices.'),
    (Icons.refresh_rounded, ZapColors.info,
        'Silent auto-refresh via Dio interceptor',
        'Callers never see 401 errors. Token refresh is invisible to UI layer.'),
    (Icons.delete_forever_rounded, ZapColors.warning,
        'Clear on refresh failure',
        'If the refresh token is expired or revoked, force re-auth. Never leave stale tokens.'),
    (Icons.memory_rounded, ZapColors.info,
        'Never log token values',
        'No print(), debugPrint(), or Sentry breadcrumbs with token strings.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rules.map((r) {
        final (icon, color, title, detail) = r;
        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(detail,
                        style: const TextStyle(
                            color: Color(0xFF9E9EB8),
                            fontSize: 11,
                            height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
