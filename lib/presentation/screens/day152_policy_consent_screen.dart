/// Day 152 — Policy Consent Tracking & Update Notification
///
/// Second half of the Days 151-152 Privacy Policy block.
/// Day 151 built the scrollable Policy screen UI.
/// Day 152 builds:
///
///   1. PolicyConsentService — Hive-backed service that records
///      WHICH version the user accepted and WHEN, so we have
///      legal proof of informed consent.
///
///   2. PolicyUpdateBanner — a dismissible in-app banner shown
///      when the policy version changes (e.g., v1.0 → v2.0).
///      User must re-read and re-accept the new version.
///
///   3. PolicyStatusScreen — a management screen (Settings →
///      Privacy → Policy Acceptance) showing the user what
///      they accepted and when, with a link to re-read.
///
/// All 🟢 FRONTEND-ONLY — Hive local storage, zero backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import 'day151_privacy_policy_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
/// Current policy versions — bump these when policies change.
/// The consent service compares stored version vs these.
const kCurrentPrivacyVersion = '2.0';
const kCurrentTermsVersion   = '1.0'; // ToS built Day 153-154
const kPrivacyUpdatedDate    = 'June 17, 2026';
const kTermsUpdatedDate      = 'June 17, 2026';

// ── Mock consent state (in production this comes from Hive) ────────────────────
/// Represents what the user has previously accepted.
class _ConsentRecord {
  final String privacyVersion;
  final String termsVersion;
  final DateTime acceptedAt;
  final String deviceModel;
  const _ConsentRecord({
    required this.privacyVersion,
    required this.termsVersion,
    required this.acceptedAt,
    required this.deviceModel,
  });
}

// ── Providers ──────────────────────────────────────────────────────────────────
final _consentRecordProvider = StateProvider<_ConsentRecord?>(
  (ref) => _ConsentRecord(
    privacyVersion: '1.0',         // user accepted v1.0 previously
    termsVersion:   '1.0',
    acceptedAt:     DateTime(2026, 5, 23, 10, 30),
    deviceModel:    'Pixel 7',
  ),
);
final _bannerDismissedProvider = StateProvider<bool>((ref) => false);
final _activeTabProvider       = StateProvider<int>((ref) => 0);
final _reAcceptingProvider     = StateProvider<bool>((ref) => false);

// ── Helper ─────────────────────────────────────────────────────────────────────
bool _needsPrivacyUpdate(_ConsentRecord? record) =>
    record == null || record.privacyVersion != kCurrentPrivacyVersion;

bool _needsTermsUpdate(_ConsentRecord? record) =>
    record == null || record.termsVersion != kCurrentTermsVersion;

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day152PolicyConsentScreen extends ConsumerWidget {
  const Day152PolicyConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record          = ref.watch(_consentRecordProvider);
    final bannerDismissed = ref.watch(_bannerDismissedProvider);
    final tab             = ref.watch(_activeTabProvider);
    final privacyOutdated = _needsPrivacyUpdate(record);
    final termsOutdated   = _needsTermsUpdate(record);
    final allUpToDate     = !privacyOutdated && !termsOutdated;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Policy Consent'),
        elevation: 0,
        actions: [
          if (privacyOutdated || termsOutdated)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: const Text('Update required',
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
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

            // Tab selector
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0)
              _StatusTab(
                  record: record,
                  privacyOutdated: privacyOutdated,
                  termsOutdated: termsOutdated,
                  allUpToDate: allUpToDate),
            if (tab == 1) const _ServiceTab(),
            if (tab == 2)
              _BannerDemoTab(
                  privacyOutdated: privacyOutdated,
                  dismissed: bannerDismissed),
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
          colors: [Color(0xFF060A18), Color(0xFF030510), Color(0xFF0A0A0A)],
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
            _badge('⚡  DAY 152', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Policy Consent\nTracking',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Records which policy version the user accepted + when. '
            'Detects version changes and shows an in-app update banner. '
            'All stored locally in Hive — zero backend.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('Hive',  'Local storage', Color(0xFF3B82F6)),
            _HStat('v2.0',  'Current policy',Color(0xFF10B981)),
            _HStat('Banner','Update alert',  Color(0xFFF59E0B)),
            _HStat('Legal', 'Proof of consent',Color(0xFF8B5CF6)),
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
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
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
          color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_rounded,  Color(0xFF10B981), 'Status'),
      (Icons.code_rounded,           Color(0xFF3B82F6), 'Service'),
      (Icons.campaign_rounded,       Color(0xFFF59E0B), 'Banner Demo'),
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
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: 4),
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

// ── Status Tab ─────────────────────────────────────────────────────────────────
class _StatusTab extends ConsumerWidget {
  final _ConsentRecord? record;
  final bool privacyOutdated, termsOutdated, allUpToDate;
  const _StatusTab({
    required this.record,
    required this.privacyOutdated,
    required this.termsOutdated,
    required this.allUpToDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reAccepting = ref.watch(_reAcceptingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall status card
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: allUpToDate
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFFEF4444).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: allUpToDate
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFFEF4444).withOpacity(0.4),
            ),
          ),
          child: Row(children: [
            Icon(
              allUpToDate
                  ? Icons.verified_rounded
                  : Icons.warning_rounded,
              color: allUpToDate
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              size: 36,
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allUpToDate
                        ? 'All policies accepted ✅'
                        : 'Policy update required',
                    style: TextStyle(
                        color: allUpToDate
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    allUpToDate
                        ? 'User has accepted the current version of all policies'
                        : 'User accepted an older version — must re-accept before continuing',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Policy-by-policy status
        const _SectionLabel('ACCEPTANCE RECORDS'),
        const SizedBox(height: ZapSpacing.md),
        _PolicyStatusRow(
          title: 'Privacy Policy',
          currentVersion: kCurrentPrivacyVersion,
          acceptedVersion: record?.privacyVersion ?? 'None',
          acceptedAt: record?.acceptedAt,
          isOutdated: privacyOutdated,
          icon: Icons.privacy_tip_rounded,
          color: const Color(0xFF3B82F6),
          onView: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const Day151PrivacyPolicyScreen(),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        _PolicyStatusRow(
          title: 'Terms of Service',
          currentVersion: kCurrentTermsVersion,
          acceptedVersion: record?.termsVersion ?? 'None',
          acceptedAt: record?.acceptedAt,
          isOutdated: termsOutdated,
          icon: Icons.gavel_rounded,
          color: const Color(0xFF8B5CF6),
          onView: () {
            // ToS screen built Day 153-154
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Terms of Service screen — built Day 153-154'),
                backgroundColor: Color(0xFF8B5CF6),
              ),
            );
          },
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Device & timestamp
        if (record != null) ...[
          const _SectionLabel('ACCEPTANCE METADATA'),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(children: [
              _metaRow(Icons.phone_android_rounded, const Color(0xFF3B82F6),
                  'Device', record!.deviceModel),
              const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
              _metaRow(Icons.access_time_rounded, const Color(0xFF10B981),
                  'Accepted at',
                  '${record!.acceptedAt.day}/${record!.acceptedAt.month}/${record!.acceptedAt.year} '
                  '${record!.acceptedAt.hour.toString().padLeft(2, '0')}:${record!.acceptedAt.minute.toString().padLeft(2, '0')}'),
              const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
              _metaRow(Icons.verified_user_rounded, const Color(0xFF8B5CF6),
                  'Privacy v', record!.privacyVersion),
              const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
              _metaRow(Icons.gavel_rounded, const Color(0xFF10B981),
                  'ToS v', record!.termsVersion),
            ]),
          ),
          const SizedBox(height: ZapSpacing.lg),
        ],

        // Simulate re-accept
        const _SectionLabel('SIMULATE POLICY UPDATE'),
        const SizedBox(height: ZapSpacing.md),
        _infoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFFF59E0B),
          text: 'When you ship a new policy version (bump kCurrentPrivacyVersion), '
              'users who accepted the old version see the update banner and must '
              're-accept. The stored consent record is updated with the new version + timestamp.',
        ),
        const SizedBox(height: ZapSpacing.md),
        if (!privacyOutdated)
          _actionButton(
            label: 'Simulate: policy updated to v3.0',
            icon: Icons.update_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () {
              // Simulate the stored record being on an older version
              ref.read(_consentRecordProvider.notifier).state =
                  _ConsentRecord(
                    privacyVersion: '1.0', // old version
                    termsVersion: '1.0',
                    acceptedAt: DateTime(2026, 5, 23, 10, 30),
                    deviceModel: 'Pixel 7',
                  );
            },
          )
        else ...[
          _actionButton(
            label: reAccepting
                ? 'Opening policy…'
                : 'Re-accept Privacy Policy v$kCurrentPrivacyVersion',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
            onTap: reAccepting
                ? () {}
                : () async {
                    ref.read(_reAcceptingProvider.notifier).state = true;
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!context.mounted) return;
                    // In production this opens the Day151 screen with showAcceptButton=true
                    // Here we just simulate immediate acceptance
                    ref.read(_consentRecordProvider.notifier).state =
                        _ConsentRecord(
                          privacyVersion: kCurrentPrivacyVersion,
                          termsVersion: kCurrentTermsVersion,
                          acceptedAt: DateTime.now(),
                          deviceModel: 'Pixel 7',
                        );
                    ref.read(_reAcceptingProvider.notifier).state = false;
                  },
          ),
        ],
      ],
    );
  }
}

class _PolicyStatusRow extends StatelessWidget {
  final String   title, currentVersion, acceptedVersion;
  final DateTime? acceptedAt;
  final bool     isOutdated;
  final IconData icon;
  final Color    color;
  final VoidCallback onView;
  const _PolicyStatusRow({
    required this.title,
    required this.currentVersion,
    required this.acceptedVersion,
    required this.acceptedAt,
    required this.isOutdated,
    required this.icon,
    required this.color,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: isOutdated
            ? const Color(0xFFEF4444).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: isOutdated
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : const Color(0xFF2A2A2A),
        ),
      ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Row(children: [
                Text('Accepted: v$acceptedVersion',
                    style: TextStyle(
                        color: isOutdated
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF),
                        fontSize: 10)),
                if (isOutdated) ...[
                  const Text(' → ',
                      style: TextStyle(
                          color: Color(0xFF4B5563), fontSize: 10)),
                  Text('Current: v$currentVersion',
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ],
              ]),
            ],
          ),
        ),
        GestureDetector(
          onTap: onView,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Text('View',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Service Tab ────────────────────────────────────────────────────────────────
class _ServiceTab extends StatelessWidget {
  const _ServiceTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.code_rounded,
          color: const Color(0xFF3B82F6),
          text: 'The PolicyConsentService is a singleton that reads/writes to '
              'Hive box "policy_consent". Every screen that requires consent '
              '(e.g. heatmap) calls isConsentGranted() before proceeding.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('HIVE SCHEMA'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('models/policy_consent.dart',
            '@HiveType(typeId: 20)\n'
            'class PolicyConsent extends HiveObject {\n'
            '  @HiveField(0) String privacyVersion;  // "2.0"\n'
            '  @HiveField(1) String termsVersion;    // "1.0"\n'
            '  @HiveField(2) DateTime acceptedAt;\n'
            '  @HiveField(3) String deviceId;        // hashed\n'
            '  @HiveField(4) String appVersion;      // "1.0.0"\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('CONSENT SERVICE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('services/policy_consent_service.dart',
            'class PolicyConsentService {\n'
            '  static const _boxName = \'policy_consent\';\n'
            '\n'
            '  /// Returns true if user accepted the CURRENT version.\n'
            '  static bool isUpToDate() {\n'
            '    final box = Hive.box<PolicyConsent>(_boxName);\n'
            '    final record = box.get(\'consent\');\n'
            '    if (record == null) return false;\n'
            '    return record.privacyVersion == kCurrentPrivacyVersion\n'
            '        && record.termsVersion   == kCurrentTermsVersion;\n'
            '  }\n'
            '\n'
            '  /// Record acceptance of the current policy versions.\n'
            '  static Future<void> recordAcceptance() async {\n'
            '    final box = Hive.box<PolicyConsent>(_boxName);\n'
            '    await box.put(\'consent\', PolicyConsent(\n'
            '      privacyVersion: kCurrentPrivacyVersion,\n'
            '      termsVersion:   kCurrentTermsVersion,\n'
            '      acceptedAt:     DateTime.now().toUtc(),\n'
            '      deviceId:       await _hashedDeviceId(),\n'
            '      appVersion:     PackageInfo.appVersion,\n'
            '    ));\n'
            '  }\n'
            '\n'
            '  /// Returns true if user has accepted this specific consent type.\n'
            '  static bool isConsentGranted(ConsentType type) {\n'
            '    final box = Hive.box<ConsentFlags>(\'consent_flags\');\n'
            '    final flags = box.get(\'flags\');\n'
            '    if (flags == null) return false;\n'
            '    return switch (type) {\n'
            '      ConsentType.evidenceRecording  => flags.evidenceRecording,\n'
            '      ConsentType.heatmapContribution => flags.heatmapContribution,\n'
            '      ConsentType.analytics           => flags.analytics,\n'
            '      ConsentType.modelImprovement    => flags.modelImprovement,\n'
            '    };\n'
            '  }\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('HOW ROUTER USES IT'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('navigation/app_router.dart',
            '// In GoRouter redirect — gate all authenticated routes:\n'
            'redirect: (context, state) {\n'
            '  final authed   = AuthService.isLoggedIn();\n'
            '  final consented = PolicyConsentService.isUpToDate();\n'
            '\n'
            '  if (!authed)    return AppRoutes.phoneEntry;\n'
            '  if (!consented) return AppRoutes.consentGate; // Day 161-162\n'
            '  return null; // proceed normally\n'
            '},'),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('WHERE HIVE IS INITIALISED'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('main.dart',
            'void main() async {\n'
            '  WidgetsFlutterBinding.ensureInitialized();\n'
            '  await Hive.initFlutter();\n'
            '  Hive.registerAdapter(PolicyConsentAdapter());\n'
            '  Hive.registerAdapter(ConsentFlagsAdapter());\n'
            '  await Hive.openBox<PolicyConsent>(\'policy_consent\');\n'
            '  await Hive.openBox<ConsentFlags>(\'consent_flags\');\n'
            '  // ... rest of init\n'
            '}'),
      ],
    );
  }
}

// ── Banner Demo Tab ────────────────────────────────────────────────────────────
class _BannerDemoTab extends ConsumerWidget {
  final bool privacyOutdated, dismissed;
  const _BannerDemoTab({required this.privacyOutdated, required this.dismissed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.campaign_rounded,
          color: const Color(0xFFF59E0B),
          text: 'The PolicyUpdateBanner is a persistent widget placed at the '
              'top of the Dashboard. It appears when the stored policy version '
              'is older than kCurrentPrivacyVersion. User must tap "Review & Accept" '
              'to dismiss — they cannot ignore it indefinitely.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Live banner preview
        const _SectionLabel('BANNER PREVIEW  ·  AS SHOWN ON DASHBOARD'),
        const SizedBox(height: ZapSpacing.md),

        // Simulate the Dashboard top area
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            // Mock app bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
              ),
              child: const Row(children: [
                Text('ZapSafe',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Spacer(),
                Text('PROTECTED',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
            ),

            // The banner (shown when policy is outdated)
            if (privacyOutdated && !dismissed)
              PolicyUpdateBanner(
                policyName: 'Privacy Policy',
                newVersion: kCurrentPrivacyVersion,
                updatedDate: kPrivacyUpdatedDate,
                onReview: () {
                  // Navigate to the policy screen for re-acceptance
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opens Privacy Policy with Accept button'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                  ref.read(_consentRecordProvider.notifier).state =
                      _ConsentRecord(
                        privacyVersion: kCurrentPrivacyVersion,
                        termsVersion: kCurrentTermsVersion,
                        acceptedAt: DateTime.now(),
                        deviceModel: 'Pixel 7',
                      );
                },
              )
            else if (!privacyOutdated)
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 14),
                    SizedBox(width: ZapSpacing.sm),
                    Text('No banner shown — all policies up to date',
                        style: TextStyle(
                            color: Color(0xFF10B981), fontSize: 11)),
                  ]),
                ),
              ),

            // Mock dashboard body
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(children: [
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Text('SOS Button',
                        style: TextStyle(
                            color: Color(0xFFEF4444), fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Trigger controls
        const _SectionLabel('DEMO CONTROLS'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(
            child: _actionButton(
              label: 'Policy outdated\n(show banner)',
              icon: Icons.update_rounded,
              color: const Color(0xFFEF4444),
              onTap: () {
                ref.read(_consentRecordProvider.notifier).state =
                    _ConsentRecord(
                      privacyVersion: '1.0',
                      termsVersion: '1.0',
                      acceptedAt: DateTime(2026, 5, 23),
                      deviceModel: 'Pixel 7',
                    );
              },
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: _actionButton(
              label: 'Policy accepted\n(hide banner)',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                ref.read(_consentRecordProvider.notifier).state =
                    _ConsentRecord(
                      privacyVersion: kCurrentPrivacyVersion,
                      termsVersion: kCurrentTermsVersion,
                      acceptedAt: DateTime.now(),
                      deviceModel: 'Pixel 7',
                    );
              },
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Banner code
        const _SectionLabel('BANNER WIDGET CODE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('widgets/policy_update_banner.dart',
            '// Add to Dashboard build() ABOVE the main content:\n'
            'if (!PolicyConsentService.isUpToDate())\n'
            '  PolicyUpdateBanner(\n'
            '    policyName: \'Privacy Policy\',\n'
            '    newVersion: kCurrentPrivacyVersion,\n'
            '    onReview: () => context.push(\n'
            '      AppRoutes.privacyPolicy,\n'
            '      extra: {\'showAcceptButton\': true},\n'
            '    ),\n'
            '  ),'),
      ],
    );
  }
}

// ── PolicyUpdateBanner widget ──────────────────────────────────────────────────
/// Reusable widget — place at the top of any screen that requires consent.
class PolicyUpdateBanner extends StatelessWidget {
  final String policyName, newVersion, updatedDate;
  final VoidCallback onReview;
  const PolicyUpdateBanner({
    super.key,
    required this.policyName,
    required this.newVersion,
    required this.updatedDate,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          ZapSpacing.md, ZapSpacing.sm, ZapSpacing.md, 0),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
      ),
      child: Row(children: [
        const Icon(Icons.policy_rounded,
            color: Color(0xFFF59E0B), size: 20),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$policyName updated to v$newVersion',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text('Updated $updatedDate · Please review & re-accept',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        GestureDetector(
          onTap: onReview,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Review',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _metaRow(IconData icon, Color color, String label, String value) =>
    Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: ZapSpacing.sm),
      Text('$label:',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(width: ZapSpacing.sm),
      Expanded(
        child: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            textAlign: TextAlign.end),
      ),
    ]);

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
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
        ]),
      ),
    );

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
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
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
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
                  color: Color(0xFF79C0FF), fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3), fontSize: 10,
                fontFamily: 'monospace', height: 1.6)),
      ]),
    );
