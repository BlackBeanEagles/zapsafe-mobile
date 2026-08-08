/// Day 139 — Security Review & Pre-Submission Checklist
///
/// Second half of the Days 138-139 final polish cycle.
/// Day 138: 4 bug fixes + WCAG accessibility audit (first pass).
/// Day 139:
///   1. Security review — scan for data leaks, hardcoded secrets,
///      insecure network calls, over-broad permissions
///   2. Final pre-submission checklist — everything the App Store
///      and Play Store require before a public-facing release
///   3. Day 140 gate — sign off that v0.5-beta-final is ready to tag
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _securityProvider     = StateProvider<List<bool?>>(
  (ref) => List.filled(_kSecurityChecks.length, null),
);
final _preSubProvider       = StateProvider<List<bool>>(
  (ref) => List.filled(_kPreSubChecks.length, false),
);
final _gateProvider         = StateProvider<_GateState>(
  (ref) => _GateState.locked,
);
final _scanStateProvider    = StateProvider<_ScanState>(
  (ref) => _ScanState.idle,
);

enum _GateState { locked, open, tagged }
enum _ScanState { idle, scanning, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _SecurityCheck {
  final String category;
  final String item;
  final String guidance;
  final bool   critical; // P0 — must pass before any public release
  const _SecurityCheck(this.category, this.item, this.guidance,
      {this.critical = false});
}

const _kSecurityChecks = [
  // Secrets
  _SecurityCheck('Secrets', 'No hardcoded API keys in source code',
      'grep -r "API_KEY\\|SECRET\\|password" lib/ — must return 0 results',
      critical: true),
  _SecurityCheck('Secrets', 'No .env files committed to Git',
      'git ls-files | grep -i ".env" — must return 0 results', critical: true),
  _SecurityCheck('Secrets', 'Firebase google-services.json not in public repo',
      'Stored in CI secrets, not committed', critical: true),

  // Network
  _SecurityCheck('Network', 'All API calls use HTTPS (TLS 1.2+)',
      'Network security config: cleartextTrafficPermitted=false'),
  _SecurityCheck('Network', 'Certificate pinning on SOS + auth endpoints',
      'sha256 pins for api.zapsafe.app — stored in network_security_config.xml'),
  _SecurityCheck('Network', 'API responses never logged in production',
      'Log level DEBUG only in debug builds — release strips all logs'),

  // Data privacy
  _SecurityCheck('Privacy', 'Raw audio NEVER uploaded to server',
      'Only SHA-256 hash + confidence score sent — verify in Wireshark trace',
      critical: true),
  _SecurityCheck('Privacy', 'GPS coordinates rounded to 10m precision before upload',
      'GpsService.sanitise() called before any API call'),
  _SecurityCheck('Privacy', 'No user PII in Sentry error reports',
      'Sentry beforeSend hook strips phone number, location, contact names'),

  // Storage
  _SecurityCheck('Storage', 'JWT tokens stored in Android Keystore / iOS Keychain',
      'FlutterSecureStorage — NOT SharedPreferences', critical: true),
  _SecurityCheck('Storage', 'Evidence files encrypted at rest (AES-256)',
      'File.writeAsBytes with AES key from Keystore'),
  _SecurityCheck('Storage', 'No sensitive data in app logs (logcat)',
      'Run: adb logcat | grep -i "token\\|password\\|phone" — 0 matches'),

  // Permissions
  _SecurityCheck('Permissions', 'Only necessary permissions declared in manifest',
      'Audit AndroidManifest.xml — remove any unused permission'),
  _SecurityCheck('Permissions', 'Location permission not requested until needed',
      'First requested when Journey Mode / Safety Map opened for first time'),
  _SecurityCheck('Permissions', 'Camera not accessed in background',
      'Camera only active during SOS_ACTIVE state — verified by foreground service'),
];

class _PreSubCheck {
  final String category;
  final String item;
  final Color  color;
  const _PreSubCheck(this.category, this.item, this.color);
}

const _kPreSubChecks = [
  // App Store assets
  _PreSubCheck('App Store', 'App icon: 1024×1024px, no alpha, no rounded corners', Color(0xFF3B82F6)),
  _PreSubCheck('App Store', 'Screenshots: 5 per device size (iPhone 15, SE, iPad)', Color(0xFF3B82F6)),
  _PreSubCheck('App Store', 'App preview video (optional, 15-30s)', Color(0xFF3B82F6)),
  _PreSubCheck('App Store', 'Short description (30 chars) + full description', Color(0xFF3B82F6)),

  // Privacy & legal
  _PreSubCheck('Legal', 'Privacy policy URL: https://zapsafe.app/privacy', Color(0xFF8B5CF6)),
  _PreSubCheck('Legal', 'Terms of service URL: https://zapsafe.app/terms', Color(0xFF8B5CF6)),
  _PreSubCheck('Legal', 'Data safety form completed (Play Store)', Color(0xFF8B5CF6)),
  _PreSubCheck('Legal', 'Age rating: 4+ (no adult content)', Color(0xFF8B5CF6)),

  // Technical
  _PreSubCheck('Technical', 'Target SDK: Android 14 (API 34), iOS 17', Color(0xFF10B981)),
  _PreSubCheck('Technical', 'Min SDK: Android 7 (API 24), iOS 15', Color(0xFF10B981)),
  _PreSubCheck('Technical', 'Release build signed with production keystore', Color(0xFF10B981)),
  _PreSubCheck('Technical', 'No debug flags or test code in release build', Color(0xFF10B981)),
  _PreSubCheck('Technical', 'App size: Android AAB < 50 MB, iOS IPA < 60 MB', Color(0xFF10B981)),

  // Quality
  _PreSubCheck('Quality', 'Crash-free rate > 99.5% (Sentry: 0.09% crash rate ✅)', Color(0xFFF59E0B)),
  _PreSubCheck('Quality', 'No ANR events in last 7 days', Color(0xFFF59E0B)),
  _PreSubCheck('Quality', 'WCAG 2.1 AA accessibility audit passed (Day 138)', Color(0xFFF59E0B)),
  _PreSubCheck('Quality', '1,000 beta testers — no critical issues pending', Color(0xFFF59E0B)),
];

// Security scan findings (simulated)
const _kScanFindings = [
  (true,  'No hardcoded secrets found in 2,847 source files'),
  (true,  'All 23 API endpoints use HTTPS TLS 1.2+'),
  (true,  'Raw audio confirmed not in any network payload (Wireshark)'),
  (true,  'JWT stored in Android Keystore — verified via key attestation'),
  (false, 'WARNING: 1 log statement prints phone number in DEBUG mode'),
  (true,  'GPS sanitisation confirmed — 10m precision before upload'),
  (true,  'Sentry PII scrubbing active — no phone/location in reports'),
  (true,  'Evidence files AES-256 encrypted — verified by hex dump'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day139SecurityReviewScreen extends ConsumerWidget {
  const Day139SecurityReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 139 · Security Review'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _SecurityTab(),
            if (tab == 1) const _PreSubTab(),
            if (tab == 2) const _GateTab(),
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0D1A), Color(0xFF050710), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 139', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Final Polish Day 2', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Security Review &\nPre-Submission',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Last day before Day 140 tag. '
            '15-point security scan, 17-point pre-submission checklist, '
            'then open the Day 140 gate to tag v0.5-beta-final.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('15',    'Security checks',  Color(0xFF3B82F6)),
            _HStat('17',    'Pre-sub checks',   Color(0xFF8B5CF6)),
            _HStat('1',     'Warning found',    Color(0xFFF59E0B)),
            _HStat('D140',  'Next: tag',        Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.security_rounded,      Color(0xFF3B82F6), 'Security'),
      (Icons.checklist_rounded,     Color(0xFF8B5CF6), 'Pre-Submit'),
      (Icons.flag_rounded,          Color(0xFF10B981), 'D140 Gate'),
    ];
    return Row(
      children: List.generate(3, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Security Tab ───────────────────────────────────────────────────────────────
class _SecurityTab extends ConsumerWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_securityProvider);
    final scanState = ref.watch(_scanStateProvider);
    final passCount = checks.where((c) => c == true).length;
    final failCount = checks.where((c) => c == false).length;
    final pending   = checks.where((c) => c == null).length;
    final critFail  = _kSecurityChecks.asMap().entries
        .where((e) => e.value.critical && checks[e.key] == false)
        .length;

    // Group by category
    final categories = <String, List<int>>{};
    for (int i = 0; i < _kSecurityChecks.length; i++) {
      categories.putIfAbsent(_kSecurityChecks[i].category, () => []).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Automated scan
        const _SectionLabel('AUTOMATED SECURITY SCAN'),
        const SizedBox(height: ZapSpacing.md),
        _AutoScanCard(state: scanState, checks: checks),
        const SizedBox(height: ZapSpacing.xl),

        // Summary
        _SecuritySummary(
            passCount: passCount,
            failCount: failCount,
            pending: pending,
            critFail: critFail),
        const SizedBox(height: ZapSpacing.lg),

        // Checklist by category
        const _SectionLabel('MANUAL VERIFICATION  ·  TAP TO AUDIT'),
        const SizedBox(height: ZapSpacing.md),
        ...categories.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _SecurityCategory(
                  category: entry.key,
                  indices: entry.value,
                  checks: checks,
                  ref: ref),
            )),
      ],
    );
  }
}

class _AutoScanCard extends ConsumerWidget {
  final _ScanState state;
  final List<bool?> checks;
  const _AutoScanCard({required this.state, required this.checks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: state == _ScanState.done
            ? const Color(0xFF1A3A1A)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _ScanState.done
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        _codeNote('terminal',
            '# Run security scan\n'
            'flutter analyze --fatal-infos\n'
            'grep -r "http://" lib/     # should be 0\n'
            'grep -r "API_KEY\\|SECRET" lib/ # should be 0\n'
            'dart pub audit             # check for vulnerabilities'),
        const SizedBox(height: ZapSpacing.md),

        if (state == _ScanState.idle)
          _actionButton(
            label: 'Run automated security scan',
            icon: Icons.security_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              ref.read(_scanStateProvider.notifier).state = _ScanState.scanning;
              await Future.delayed(const Duration(milliseconds: 1800));
              if (!context.mounted) return;
              ref.read(_scanStateProvider.notifier).state = _ScanState.done;
              // Auto-apply scan results to checklist
              final updated = List<bool?>.from(ref.read(_securityProvider));
              for (int i = 0; i < _kScanFindings.length && i < updated.length; i++) {
                updated[i] = _kScanFindings[i].$1;
              }
              ref.read(_securityProvider.notifier).state = updated;
            },
          )
        else if (state == _ScanState.scanning)
          _statusChip(Icons.radar_rounded, const Color(0xFF3B82F6),
              'Scanning 2,847 source files…', loading: true)
        else ...[
          // Findings
          ...List.generate(_kScanFindings.length, (i) {
            final (pass, msg) = _kScanFindings[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    pass ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: pass ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(msg,
                        style: TextStyle(
                            color: pass ? const Color(0xFF9CA3AF) : Colors.white,
                            fontSize: 11,
                            height: 1.4)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_rounded, color: Color(0xFFF59E0B), size: 14),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  '1 WARNING: Remove phone number log in debug mode '
                  '(lib/data/services/auth_service.dart:47). '
                  'Non-critical — already stripped in release build.',
                  style: TextStyle(
                      color: Color(0xFFF59E0B), fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _SecuritySummary extends StatelessWidget {
  final int passCount, failCount, pending, critFail;
  const _SecuritySummary({
    required this.passCount,
    required this.failCount,
    required this.pending,
    required this.critFail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _box('$passCount', 'Pass', const Color(0xFF10B981)),
      const SizedBox(width: ZapSpacing.sm),
      _box('$failCount', 'Fail', failCount > 0
          ? const Color(0xFFEF4444)
          : const Color(0xFF4B5563)),
      const SizedBox(width: ZapSpacing.sm),
      _box('$pending', 'Pending', const Color(0xFF6B7280)),
      const SizedBox(width: ZapSpacing.sm),
      _box('$critFail', 'Crit. Fail',
          critFail > 0 ? const Color(0xFFEF4444) : const Color(0xFF4B5563)),
    ]);
  }

  Widget _box(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _SecurityCategory extends StatelessWidget {
  final String      category;
  final List<int>   indices;
  final List<bool?> checks;
  final WidgetRef   ref;
  const _SecurityCategory({
    required this.category,
    required this.indices,
    required this.checks,
    required this.ref,
  });

  static const _catColors = {
    'Secrets': Color(0xFFEF4444),
    'Network': Color(0xFF3B82F6),
    'Privacy': Color(0xFF8B5CF6),
    'Storage': Color(0xFF10B981),
    'Permissions': Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final color    = _catColors[category] ?? const Color(0xFF9CA3AF);
    final passInCat= indices.where((i) => checks[i] == true).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusSmall - 1)),
          ),
          child: Row(children: [
            Container(
                width: 8, height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: ZapSpacing.sm),
            Text(category,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text('$passInCat/${indices.length}',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        ...indices.asMap().entries.map((e) {
          final ii     = e.key;
          final idx    = e.value;
          final check  = _kSecurityChecks[idx];
          final result = checks[idx];
          final isLast = ii == indices.length - 1;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (check.critical)
                    Container(
                      margin: const EdgeInsets.only(right: 4, top: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('P0',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(check.item,
                            style: TextStyle(
                              color: result == false
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                              fontSize: 12,
                            )),
                        Text(check.guidance,
                            style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                                height: 1.3,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Row(children: [
                    _btn('✅', result == true, const Color(0xFF10B981), () {
                      final u = List<bool?>.from(ref.read(_securityProvider));
                      u[idx] = true;
                      ref.read(_securityProvider.notifier).state = u;
                    }),
                    const SizedBox(width: ZapSpacing.xs),
                    _btn('❌', result == false, const Color(0xFFEF4444), () {
                      final u = List<bool?>.from(ref.read(_securityProvider));
                      u[idx] = false;
                      ref.read(_securityProvider.notifier).state = u;
                    }),
                  ]),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }),
      ]),
    );
  }

  Widget _btn(String label, bool sel, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: sel ? color.withOpacity(0.5) : const Color(0xFF2A2A2A)),
          ),
          child: Center(child: Text(label, style: const TextStyle(fontSize: 14))),
        ),
      );
}

// ── Pre-Submission Tab ─────────────────────────────────────────────────────────
class _PreSubTab extends ConsumerWidget {
  const _PreSubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_preSubProvider);
    final doneCount = checks.where((c) => c).length;
    final allDone   = doneCount == _kPreSubChecks.length;

    // Group
    final categories = <String, List<int>>{};
    for (int i = 0; i < _kPreSubChecks.length; i++) {
      categories.putIfAbsent(_kPreSubChecks[i].category, () => []).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: allDone
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: allDone
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / ${_kPreSubChecks.length} ready',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  allDone
                      ? '✅ Ready for App Store submission'
                      : 'Tap each item to confirm',
                  style: TextStyle(
                      color: allDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / _kPreSubChecks.length,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  allDone ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                ),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Category groups
        ...categories.entries.map((entry) {
          final cat     = entry.key;
          final indices = entry.value;
          final color   = _kPreSubChecks[indices.first].color;
          final passCount = indices.where((i) => checks[i]).length;

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(children: [
                // Cat header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(ZapSpacing.radiusSmall - 1)),
                  ),
                  child: Row(children: [
                    Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(cat,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Text('$passCount/${indices.length}',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                // Items
                ...indices.asMap().entries.map((e) {
                  final ii     = e.key;
                  final idx    = e.value;
                  final done   = checks[idx];
                  final isLast = ii == indices.length - 1;

                  return GestureDetector(
                    onTap: () {
                      final updated = List<bool>.from(ref.read(_preSubProvider));
                      updated[idx] = !updated[idx];
                      ref.read(_preSubProvider.notifier).state = updated;
                    },
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.md, vertical: 12),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: done
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF4B5563)),
                            ),
                            child: done
                                ? const Icon(Icons.check_rounded,
                                    color: Color(0xFF10B981), size: 14)
                                : null,
                          ),
                          const SizedBox(width: ZapSpacing.md),
                          Expanded(
                            child: Text(
                              _kPreSubChecks[idx].item,
                              style: TextStyle(
                                color: done
                                    ? const Color(0xFF6B7280)
                                    : Colors.white,
                                fontSize: 12,
                                decoration:
                                    done ? TextDecoration.lineThrough : null,
                                decorationColor: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
                    ]),
                  );
                }),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

// ── Gate Tab ───────────────────────────────────────────────────────────────────
class _GateTab extends ConsumerWidget {
  const _GateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateState  = ref.watch(_gateProvider);
    final secChecks  = ref.watch(_securityProvider);
    final preChecks  = ref.watch(_preSubProvider);
    final secPass    = secChecks.where((c) => c == true).length;
    final secCritFail= _kSecurityChecks.asMap().entries
        .where((e) => e.value.critical && secChecks[e.key] == false).length;
    final prePass    = preChecks.where((c) => c).length;
    final canOpen    = secCritFail == 0 && prePass == _kPreSubChecks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status summary
        const _SectionLabel('READINESS SUMMARY'),
        const SizedBox(height: ZapSpacing.md),
        _ReadinessSummary(
          secPass: secPass,
          secTotal: _kSecurityChecks.length,
          secCritFail: secCritFail,
          prePass: prePass,
          preTotal: _kPreSubChecks.length,
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Beta journey summary
        const _SectionLabel('BETA JOURNEY  ·  DAYS 111-139'),
        const SizedBox(height: ZapSpacing.md),
        const _BetaJourneySummary(),
        const SizedBox(height: ZapSpacing.xl),

        // Gate
        const _SectionLabel('DAY 140 GATE  ·  TAG v0.5-beta-final'),
        const SizedBox(height: ZapSpacing.md),
        _D140Gate(
            gateState: gateState,
            canOpen: canOpen,
            onOpen: () =>
                ref.read(_gateProvider.notifier).state = _GateState.open,
            onTag: () async {
              ref.read(_gateProvider.notifier).state = _GateState.tagged;
            }),
      ],
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  final int secPass, secTotal, secCritFail, prePass, preTotal;
  const _ReadinessSummary({
    required this.secPass,
    required this.secTotal,
    required this.secCritFail,
    required this.prePass,
    required this.preTotal,
  });

  @override
  Widget build(BuildContext context) {
    final secOk  = secCritFail == 0;
    final preOk  = prePass == preTotal;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _readRow(
          icon: Icons.security_rounded,
          color: secOk ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          label: 'Security review',
          value: '$secPass / $secTotal checks passed',
          sub: secCritFail == 0
              ? 'No critical failures'
              : '$secCritFail critical failure(s)',
          ok: secOk,
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _readRow(
          icon: Icons.checklist_rounded,
          color: preOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          label: 'Pre-submission',
          value: '$prePass / $preTotal items confirmed',
          sub: preOk ? 'App Store ready' : '${preTotal - prePass} remaining',
          ok: preOk,
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _readRow(
          icon: Icons.accessibility_rounded,
          color: const Color(0xFF10B981),
          label: 'Accessibility',
          value: 'WCAG 2.1 AA audit (Day 138)',
          sub: 'Completed',
          ok: true,
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _readRow(
          icon: Icons.bug_report_rounded,
          color: const Color(0xFF10B981),
          label: 'Crash rate',
          value: '0.09% (target < 0.5%)',
          sub: '✅ Well below threshold',
          ok: true,
        ),
      ]),
    );
  }

  Widget _readRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
    required bool ok,
  }) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(value,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            ]),
          ),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 20,
          ),
        ]),
      );
}

class _BetaJourneySummary extends StatelessWidget {
  const _BetaJourneySummary();

  static const _phases = [
    (Color(0xFFF97316), 'Days 111-120', 'Beta Infrastructure',
        'Flavor, onboarding, feedback FAB, Sentry, TestFlight, Play, release notes, 1K launch'),
    (Color(0xFFEF4444), 'Days 121-125', 'Crash & FP Fixes',
        'Analysis → 3 P0 crashes fixed → FP rate 7.8%→4.8% → v0.5.1-2'),
    (Color(0xFF3B82F6), 'Days 126-128', 'Notification Polish',
        'UI bugs × 4 → Samsung Doze fix → per-contact delivery → v0.5.3'),
    (Color(0xFF8B5CF6), 'Days 129-132', 'Performance & Memory',
        'Cold start 5.2s→1.8s · Battery 20%→6% · Memory 195→58 MB · 5 leaks → v0.5.4-5'),
    (Color(0xFF10B981), 'Days 133-135', 'Onboarding & Release',
        'Simplify 7→4 steps · < 2 min · 34%→9% abandon → v0.5.6 · beta-2 release'),
    (Color(0xFF06B6D4), 'Days 136-139', 'Verification & Polish',
        'Second feedback round · 4.4★ satisfaction · 4 final bugs · security review'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _phases.asMap().entries.map((e) {
          final i = e.key;
          final (color, days, title, desc) = e.value;
          final isLast = i == _phases.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 36, color: const Color(0xFF2A2A2A)),
              ]),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.md, top: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(days,
                          style: TextStyle(
                              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                    Text(desc,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            height: 1.4)),
                  ]),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _D140Gate extends StatelessWidget {
  final _GateState gateState;
  final bool canOpen;
  final VoidCallback onOpen, onTag;
  const _D140Gate({
    required this.gateState,
    required this.canOpen,
    required this.onOpen,
    required this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    if (gateState == _GateState.tagged) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF10B981).withOpacity(0.05),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
        ),
        child: const Column(children: [
          Icon(Icons.local_offer_rounded, color: Color(0xFF10B981), size: 52),
          SizedBox(height: ZapSpacing.md),
          Text('v0.5-beta-final TAGGED 🎉',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'git tag v0.5-beta-final\n'
            'Days 111-139 complete.\n'
            'App is production-ready. Day 140 = final verification.',
            style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 12,
                height: 1.6,
                fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _Chip('29 days (111-139)',  Color(0xFF10B981)),
              _Chip('Crash 0.09%',        Color(0xFF10B981)),
              _Chip('Retention D7: 43%',  Color(0xFF3B82F6)),
              _Chip('Onboarding < 2 min', Color(0xFF8B5CF6)),
              _Chip('Security ✅',         Color(0xFF10B981)),
              _Chip('WCAG 2.1 AA ✅',      Color(0xFF3B82F6)),
            ],
          ),
        ]),
      );
    }

    if (gateState == _GateState.open) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: Column(children: [
          const Icon(Icons.lock_open_rounded,
              color: Color(0xFF10B981), size: 36),
          const SizedBox(height: ZapSpacing.md),
          const Text('Gate Open — Ready to Tag',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'All security checks pass.\n'
            'All pre-submission items confirmed.\n'
            'Tap below to simulate git tag.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.lg),
          _codeNote('git',
              'git tag v0.5-beta-final -m \\\n'
              '  "Production-ready beta · Days 111-139"\n'
              'git push origin v0.5-beta-final'),
          const SizedBox(height: ZapSpacing.md),
          _actionButton(
            label: 'Tag v0.5-beta-final',
            icon: Icons.local_offer_rounded,
            color: const Color(0xFF10B981),
            onTap: onTag,
          ),
        ]),
      );
    }

    // Locked
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        if (!canOpen) ...[
          _infoBox(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            text: 'Complete security review + pre-submission checklist '
                'on the other two tabs to unlock this gate.',
          ),
          const SizedBox(height: ZapSpacing.md),
        ],
        GestureDetector(
          onTap: canOpen ? onOpen : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: canOpen
                  ? const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)])
                  : null,
              color: canOpen ? null : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              boxShadow: canOpen
                  ? [
                      BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
                    ]
                  : null,
              border: canOpen
                  ? null
                  : Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  canOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: canOpen ? Colors.white : const Color(0xFF4B5563),
                  size: 20,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  canOpen
                      ? 'Open Day 140 gate → tag v0.5-beta-final'
                      : 'Complete both checklists first',
                  style: TextStyle(
                    color: canOpen ? Colors.white : const Color(0xFF4B5563),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );

Widget _infoBox({
  required IconData icon,
  required Color color,
  required String text,
}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF),
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6)),
      ]),
    );
