/// Day 182 — Network Security Config, iOS ATS & Proxy Detection
///
/// Second day of the Days 181-182 Certificate Pinning block.
/// Day 181: SHA-256 SPKI pins, Dio interceptor, rotation plan   ✅
/// Day 182: Android Network Security Config XML, iOS ATS
///           (NSAppTransportSecurity), and proxy detection code
///           that blocks Charles/Burp on release builds.
///
/// 🟢 FRONTEND-ONLY — all configuration files and client-side logic.
///    No backend API changes required.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d182TabProvider          = StateProvider<int>((ref) => 0);
final _expandedNscProvider      = StateProvider<int?>((ref) => null);
final _expandedAtsProvider      = StateProvider<int?>((ref) => null);
final _proxyTestStateProvider   = StateProvider<_ProxyTestState>((ref) => _ProxyTestState.idle);
final _proxyTestResultsProvider = StateProvider<List<_ProxyResult>>((ref) => []);
final _buildFlavourProvider     = StateProvider<_BuildFlavour>((ref) => _BuildFlavour.release);

enum _ProxyTestState { idle, testing, done }
enum _BuildFlavour   { debug, profile, release }

// ── NSC explanation items ──────────────────────────────────────────────────────
class _NscItem {
  final String   xmlElement;
  final String   title;
  final String   explanation;
  final Color    color;
  const _NscItem({
    required this.xmlElement, required this.title,
    required this.explanation, required this.color,
  });
}

const _kNscItems = [
  _NscItem(
    xmlElement: '<base-config cleartextTrafficPermitted="false">',
    title: 'Block all cleartext (HTTP)',
    explanation: 'Prevents any HTTP (non-HTTPS) connection system-wide. '
        'All network calls must use TLS. '
        'If the app accidentally uses http:// anywhere, it crashes rather than '
        'silently leaking data.',
    color: Color(0xFF10B981),
  ),
  _NscItem(
    xmlElement: '<trust-anchors>\n  <certificates src="system"/>\n</trust-anchors>',
    title: 'Trust only system CA certificates',
    explanation: 'The app trusts only certificates signed by the device\'s '
        'built-in CA store. '
        'User-installed CA certificates (e.g. mitmproxy, Charles) are '
        'NOT trusted — they are excluded by omitting '
        '<certificates src="user"/>. '
        'This blocks proxy interception even without SPKI pinning.',
    color: Color(0xFF3B82F6),
  ),
  _NscItem(
    xmlElement: '<debug-overrides>\n  <trust-anchors>\n'
        '    <certificates src="user"/>\n  </trust-anchors>\n</debug-overrides>',
    title: 'Debug: allow user CAs (developer use only)',
    explanation: 'In debug builds only, user-installed CAs are trusted. '
        'This lets developers use Charles Proxy or mitmproxy during development '
        'without disabling security for release users. '
        'Debug overrides are stripped from release APKs automatically by Android.',
    color: Color(0xFFF59E0B),
  ),
  _NscItem(
    xmlElement: '<domain-config>\n  <domain>api.zapsafe.app</domain>\n'
        '  <pin-set expiration="2027-03-15">\n'
        '    <pin digest="SHA-256">AAAAAABBB…</pin>\n'
        '    <pin digest="SHA-256">HHHHHHHIII…</pin>\n'
        '  </pin-set>\n</domain-config>',
    title: 'Domain-level SPKI pin (Android system layer)',
    explanation: 'Android\'s built-in pinning layer as a defense-in-depth second '
        'layer below Day 181\'s Dio interceptor. '
        'Even if the Dio interceptor has a bug, Android\'s system pinning still '
        'rejects mismatched certificates. '
        'The expiration date triggers a lint warning 60 days before expiry.',
    color: Color(0xFF8B5CF6),
  ),
];

// ── ATS explanation items ──────────────────────────────────────────────────────
class _AtsItem {
  final String   plistKey;
  final String   title;
  final String   explanation;
  final Color    color;
  const _AtsItem({
    required this.plistKey, required this.title,
    required this.explanation, required this.color,
  });
}

const _kAtsItems = [
  _AtsItem(
    plistKey: 'NSAllowsArbitraryLoads = NO',
    title: 'Block all insecure connections',
    explanation: 'ATS is enabled globally (NO = "do not allow arbitrary/insecure"). '
        'All connections must use TLS 1.2 or higher. '
        'This is the most important ATS setting — never set to YES in production.',
    color: Color(0xFF10B981),
  ),
  _AtsItem(
    plistKey: 'NSAllowsLocalNetworking = NO',
    title: 'Block local network connections',
    explanation: 'Prevents connections to unprotected local IP addresses '
        '(e.g. 192.168.x.x, localhost) which could be proxies or '
        'rogue devices on the same network. '
        'If you need local dev server, only enable in Debug scheme.',
    color: Color(0xFF3B82F6),
  ),
  _AtsItem(
    plistKey: 'NSExceptionDomains:\n  api.zapsafe.app:\n    NSPinnedLeafIdentities',
    title: 'iOS-level certificate pinning',
    explanation: 'iOS 14+ supports certificate pinning via NSPinnedLeafIdentities '
        'in NSExceptionDomains. Specify the SPKI SHA-256 hash as a '
        'base64 Data value. This is a second defense layer on iOS, '
        'complementing Day 181\'s Dio interceptor.',
    color: Color(0xFF8B5CF6),
  ),
  _AtsItem(
    plistKey: 'NSRequiresCertificateTransparency = YES',
    title: 'Require Certificate Transparency',
    explanation: 'All TLS certificates must be logged in a public Certificate '
        'Transparency log. This makes it much harder for a CA to issue '
        'rogue certs for zapsafe.app without it being publicly detectable.',
    color: Color(0xFFF59E0B),
  ),
];

// ── Proxy detection results ────────────────────────────────────────────────────
class _ProxyResult {
  final String   check;
  final bool     detected;    // true = proxy detected (bad on release)
  final String   detail;
  final Color    color;
  const _ProxyResult({
    required this.check, required this.detected,
    required this.detail, required this.color,
  });
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day182NetworkSecurityScreen extends ConsumerWidget {
  const Day182NetworkSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d182TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Network Security Config'),
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
            child: const Text('🟢 FRONTEND-ONLY',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
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
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_d182TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _AndroidNscTab(),
            if (tab == 1) const _IosAtsTab(),
            if (tab == 2) const _ProxyDetectionTab(),
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
            colors: [Color(0xFF080C14), Color(0xFF050810), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 182',              const Color(0xFF3B82F6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section C  ·  Day 2/10',   const Color(0xFF8B5CF6)),
          _badge('Cert Pinning  ·  Day 2/2', const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Network Security\nConfig & ATS',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Android network_security_config.xml — cleartext blocked, '
          'user CAs excluded, SPKI pins declared. '
          'iOS NSAppTransportSecurity — ATS enforced. '
          'Proxy detection blocks Charles/Burp on release builds.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('4',    '4 NSC rules',      Color(0xFF3DDC84)),
          _HStat('4',    '4 ATS keys',       Color(0xFF9CA3AF)),
          _HStat('5',    '5 proxy checks',   Color(0xFF8B5CF6)),
          _HStat('0',    '0 HTTP leaks',     Color(0xFF10B981)),
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
      (Icons.android_rounded,    Color(0xFF3DDC84), 'Android NSC'),
      (Icons.apple_rounded,      Color(0xFF9CA3AF), 'iOS ATS'),
      (Icons.vpn_lock_rounded,   Color(0xFF8B5CF6), 'Proxy Detection'),
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
            const SizedBox(height: 4),
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
// TAB 1 — Android Network Security Config
// ══════════════════════════════════════════════════════════════════════════════
class _AndroidNscTab extends ConsumerWidget {
  const _AndroidNscTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedNscProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.android_rounded, color: const Color(0xFF3DDC84),
          text: 'network_security_config.xml is Android\'s declarative security '
              'config. It is referenced in AndroidManifest.xml and enforced '
              'by the Android runtime — no code needed. '
              'File location: android/app/src/main/res/xml/network_security_config.xml'),
      const SizedBox(height: ZapSpacing.lg),

      // AndroidManifest.xml reference
      const _SectionLabel('1. REFERENCE IN ANDROIDMANIFEST.XML'),
      const SizedBox(height: ZapSpacing.md),
      _codeBlock(context, '''<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="false"
    ...>''', const Color(0xFF3DDC84)),
      const SizedBox(height: ZapSpacing.lg),

      // Full NSC file
      const _SectionLabel('2. FULL network_security_config.xml'),
      const SizedBox(height: ZapSpacing.md),
      _codeBlock(context, '''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>

  <!-- Block all cleartext (HTTP) globally -->
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors>
      <!-- Trust only system CAs — NOT user-installed CAs -->
      <certificates src="system"/>
    </trust-anchors>
  </base-config>

  <!-- Debug builds: allow user CAs for Charles/mitmproxy -->
  <debug-overrides>
    <trust-anchors>
      <certificates src="user"/>
    </trust-anchors>
  </debug-overrides>

  <!-- Domain-level SPKI pinning (second defense layer) -->
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">api.zapsafe.app</domain>
    <pin-set expiration="2027-03-15">
      <!-- Primary SPKI SHA-256 hash (api.zapsafe.app) -->
      <pin digest="SHA-256">AAAAAABBBBBBCCCCCCDDDDDDEEEEEEFFFFFFGGGGGG=</pin>
      <!-- Backup hash for zero-downtime rotation -->
      <pin digest="SHA-256">HHHHHHIIIIIIJJJJJJKKKKKKLLLLLLMMMMMMNNNNNNN=</pin>
    </pin-set>
  </domain-config>

  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">exports.zapsafe.app</domain>
    <pin-set expiration="2027-06-01">
      <pin digest="SHA-256">OOOOOOPPPPPPQQQQQQRRRRRRSSSSSSTTTTTTUUUUUU=</pin>
      <pin digest="SHA-256">VVVVVVWWWWWWXXXXXXYYYYYYYYZZZZZZ000000111=</pin>
    </pin-set>
  </domain-config>

</network-security-config>''', const Color(0xFF3DDC84)),
      const SizedBox(height: ZapSpacing.xl),

      // Explanation cards
      const _SectionLabel('4 RULES EXPLAINED  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kNscItems.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value;
        final isExp= expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedNscProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? item.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? item.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('NSC', style: TextStyle(color: item.color,
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(item.title, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(children: [
                          _codeBlock(context, item.xmlElement, item.color),
                          const SizedBox(height: ZapSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: item.color.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: item.color.withOpacity(0.2))),
                            child: Text(item.explanation, style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6))),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.lg),

      // Lint / CI check note
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3DDC84).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF3DDC84).withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF3DDC84), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Text('CI verification', style: TextStyle(color: Color(0xFF3DDC84),
                fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text(
            '• Android Lint rule MissingNetworkSecurityConfig: ERROR\n'
            '• If pin-set expiration < 60 days away: WARNING in lint output\n'
            '• build.gradle: add lint { abortOnError true } for CI hard-fail\n'
            '• Verified in Day 139 Security Review screen',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, height: 1.7)),
        ])),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — iOS ATS
// ══════════════════════════════════════════════════════════════════════════════
class _IosAtsTab extends ConsumerWidget {
  const _IosAtsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedAtsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.apple_rounded, color: const Color(0xFF9CA3AF),
          text: 'App Transport Security (ATS) is iOS\'s equivalent of Android NSC. '
              'Configured in ios/Runner/Info.plist. '
              'ATS enforces TLS 1.2+ by default. '
              'NSAllowsArbitraryLoads = YES would be a critical security hole — '
              'never set it in production.'),
      const SizedBox(height: ZapSpacing.lg),

      // Full Info.plist ATS block
      const _SectionLabel('FULL INFO.PLIST NSAppTransportSecurity BLOCK'),
      const SizedBox(height: ZapSpacing.md),
      _codeBlock(context, '''<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <!-- NEVER set this to YES in production -->
    <key>NSAllowsArbitraryLoads</key>
    <false/>

    <!-- Block local-network / mDNS proxy interception -->
    <key>NSAllowsLocalNetworking</key>
    <false/>

    <!-- Require Certificate Transparency for all connections -->
    <key>NSRequiresCertificateTransparency</key>
    <true/>

    <!-- Domain-level exceptions for iOS certificate pinning (iOS 14+) -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.zapsafe.app</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <!-- NSPinnedLeafIdentities: SHA-256 of SubjectPublicKeyInfo -->
            <key>NSPinnedLeafIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <!-- Primary pin: api.zapsafe.app -->
                    <string>AAAAAABBBBBBCCCCCCDDDDDDEEEEEEFFFFFFGGGGGG=</string>
                </dict>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <!-- Backup pin for rotation -->
                    <string>HHHHHHIIIIIIJJJJJJKKKKKKLLLLLLMMMMMMNNNNNNN=</string>
                </dict>
            </array>
        </dict>

        <key>exports.zapsafe.app</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSPinnedLeafIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>OOOOOOPPPPPPQQQQQQRRRRRRSSSSSSTTTTTTUUUUUU=</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>''', const Color(0xFF9CA3AF)),
      const SizedBox(height: ZapSpacing.xl),

      // ATS explanation cards
      const _SectionLabel('4 ATS KEYS EXPLAINED  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kAtsItems.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value;
        final isExp= expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedAtsProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? item.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? item.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('ATS', style: TextStyle(color: item.color,
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(item.title, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: const Color(0xFF2A2A2A))),
                            child: Text(item.plistKey, style: TextStyle(
                                color: item.color, fontSize: 10,
                                fontFamily: 'monospace', height: 1.5))),
                          const SizedBox(height: ZapSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: item.color.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: item.color.withOpacity(0.2))),
                            child: Text(item.explanation, style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6))),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.lg),

      // ATS vs NSC comparison
      const _SectionLabel('ATS vs ANDROID NSC  ·  FEATURE COMPARISON'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
            decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(ZapSpacing.radiusSmall),
                    topRight: Radius.circular(ZapSpacing.radiusSmall))),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('Feature',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('Android NSC',
                  style: TextStyle(color: Color(0xFF3DDC84), fontSize: 9,
                      fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('iOS ATS',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9,
                      fontWeight: FontWeight.w700))),
            ])),
          ...[
            ('Block HTTP',           '✅ cleartextTraffic', '✅ NSAllowsArbitraryLoads NO'),
            ('Exclude user CAs',     '✅ system src only',  '✅ by default'),
            ('SPKI cert pinning',    '✅ <pin-set>',        '✅ NSPinnedLeafIdentities'),
            ('Debug override',       '✅ <debug-overrides>','⚠ No built-in (use schemes)'),
            ('Cert Transparency',    '⚠ Not built-in',     '✅ NSRequiresCertificateTransparency'),
            ('Pin expiry warning',   '✅ lint warning',     '❌ No lint — manual'),
          ].asMap().entries.map((e) {
            final i = e.key;
            final (feature, android, ios) = e.value;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 9),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(feature, style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10))),
                  Expanded(flex: 2, child: Text(android, style: TextStyle(
                      color: android.startsWith('✅') ? const Color(0xFF10B981)
                          : android.startsWith('⚠') ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                      fontSize: 9))),
                  Expanded(flex: 2, child: Text(ios, style: TextStyle(
                      color: ios.startsWith('✅') ? const Color(0xFF10B981)
                          : ios.startsWith('⚠') ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                      fontSize: 9))),
                ])),
              if (i < 5) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Proxy Detection
// ══════════════════════════════════════════════════════════════════════════════
class _ProxyDetectionTab extends ConsumerWidget {
  const _ProxyDetectionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState   = ref.watch(_proxyTestStateProvider);
    final results     = ref.watch(_proxyTestResultsProvider);
    final flavour     = ref.watch(_buildFlavourProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.vpn_lock_rounded, color: const Color(0xFF8B5CF6),
          text: 'Even with cert pinning + NSC, an attacker on a rooted device '
              'can hook the SSL layer. Proxy detection adds a third layer: '
              'if a debug proxy is active, block all network on RELEASE builds.'),
      const SizedBox(height: ZapSpacing.lg),

      // Build flavour selector
      const _SectionLabel('SIMULATE BUILD FLAVOUR'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: _BuildFlavour.values.map((f) {
        final isActive = f == flavour;
        final color = switch (f) {
          _BuildFlavour.debug   => const Color(0xFFF59E0B),
          _BuildFlavour.profile => const Color(0xFF3B82F6),
          _BuildFlavour.release => const Color(0xFF10B981),
        };
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: f != _BuildFlavour.release ? 6 : 0),
          child: GestureDetector(
            onTap: () {
              ref.read(_buildFlavourProvider.notifier).state = f;
              ref.read(_proxyTestStateProvider.notifier).state = _ProxyTestState.idle;
              ref.read(_proxyTestResultsProvider.notifier).state = [];
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                      width: isActive ? 2 : 1)),
              child: Column(children: [
                Text(f.name.toUpperCase(), style: TextStyle(
                    color: isActive ? color : const Color(0xFF6B7280),
                    fontSize: 11, fontWeight: isActive ? FontWeight.w800 : FontWeight.w400)),
                Text(switch (f) {
                  _BuildFlavour.debug   => 'proxy OK',
                  _BuildFlavour.profile => 'proxy warned',
                  _BuildFlavour.release => 'proxy BLOCKED',
                }, style: TextStyle(
                    color: isActive ? color.withOpacity(0.8) : const Color(0xFF4B5563),
                    fontSize: 8)),
              ]),
            ),
          )));
      }).toList()),
      const SizedBox(height: ZapSpacing.lg),

      // 5 checks
      const _SectionLabel('5 PROXY DETECTION CHECKS'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          ...[
            ('HTTP_PROXY env var set',
                'Check for HTTP_PROXY / HTTPS_PROXY environment variables. '
                'Set by Android Debug Bridge when proxy is active.'),
            ('Non-null getSystemProxy()',
                'dart:io HttpClient.findProxyFromEnvironment detects '
                'system-level proxy configuration.'),
            ('Port 8888 / 8080 / 8443 open on localhost',
                'Charles Proxy default port is 8888; Burp Suite is 8080. '
                'If these ports respond locally, a proxy interceptor is running.'),
            ('ProxyInfo via PlatformChannel (Android)',
                'Call Connectivity.getActiveNetworkInfo().proxyInfo on Android '
                'to check if a manual proxy is configured in Wi-Fi settings.'),
            ('SSL kill-switch detection (iOS)',
                'Check if NSURLSession is being swizzled (method swizzling '
                'is a common technique used by proxy tools on iOS).'),
          ].asMap().entries.map((e) {
            final i = e.key;
            final (check, detail) = e.value;
            final isLast = i == 4;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        shape: BoxShape.circle),
                    child: Center(child: Text('${i + 1}', style: const TextStyle(
                        color: Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(check, style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(detail, style: const TextStyle(color: Color(0xFF6B7280),
                        fontSize: 10, height: 1.4)),
                  ])),
                ])),
              if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Test button
      const _SectionLabel('SIMULATED PROXY CHECK'),
      const SizedBox(height: ZapSpacing.md),

      if (testState == _ProxyTestState.idle)
        _primaryBtn(
          label: 'Run Proxy Detection (${flavour.name} mode)',
          color: const Color(0xFF8B5CF6),
          onTap: () => _runProxyTest(ref, flavour),
        )
      else if (testState == _ProxyTestState.testing)
        _ProxyTesting()
      else
        _ProxyResults(results: results, flavour: flavour, ref: ref),

      const SizedBox(height: ZapSpacing.xl),

      // Dart code
      const _SectionLabel('PROXY DETECTION CODE'),
      const SizedBox(height: ZapSpacing.md),
      _codeBlock(context, _kProxyCode, const Color(0xFF8B5CF6)),
    ]);
  }

  Future<void> _runProxyTest(WidgetRef ref, _BuildFlavour flavour) async {
    ref.read(_proxyTestStateProvider.notifier).state = _ProxyTestState.testing;
    ref.read(_proxyTestResultsProvider.notifier).state = [];

    // Simulate 5 checks
    final mock = [
      ('HTTP_PROXY env var',      false, 'Not set'),
      ('System proxy configured', false, 'No proxy in Wi-Fi settings'),
      ('Port 8888 open (Charles)',false, 'Port closed'),
      ('Port 8080 open (Burp)',   false, 'Port closed'),
      ('SSL swizzle (iOS)',       false, 'No swizzle detected'),
    ];

    final results = <_ProxyResult>[];
    for (final (check, detected, detail) in mock) {
      await Future.delayed(const Duration(milliseconds: 450));
      results.add(_ProxyResult(
        check: check, detected: detected, detail: detail,
        color: detected ? const Color(0xFFEF4444) : const Color(0xFF10B981)));
      ref.read(_proxyTestResultsProvider.notifier).state = List.from(results);
    }
    ref.read(_proxyTestStateProvider.notifier).state = _ProxyTestState.done;
  }
}

class _ProxyTesting extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_proxyTestResultsProvider);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
              color: Color(0xFF8B5CF6), strokeWidth: 2)),
          SizedBox(width: ZapSpacing.sm),
          Text('Running proxy checks…', style: TextStyle(color: Color(0xFF8B5CF6),
              fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        if (results.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.md),
          ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(r.detected ? Icons.warning_rounded : Icons.check_circle_rounded,
                    color: r.color, size: 14),
                const SizedBox(width: 6),
                Text(r.check, style: TextStyle(color: r.color, fontSize: 10)),
              ]))),
        ],
      ]));
  }
}

class _ProxyResults extends StatelessWidget {
  final List<_ProxyResult> results;
  final _BuildFlavour flavour;
  final WidgetRef ref;
  const _ProxyResults({required this.results, required this.flavour, required this.ref});

  @override
  Widget build(BuildContext context) {
    final anyDetected = results.any((r) => r.detected);
    final isBlocked   = anyDetected && flavour == _BuildFlavour.release;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: (anyDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                .withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: (anyDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                    .withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(anyDetected ? Icons.warning_rounded : Icons.verified_rounded,
                color: anyDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              anyDetected
                  ? isBlocked ? 'Proxy detected — connections BLOCKED 🔴'
                      : 'Proxy detected — allowed in ${flavour.name} mode ⚠'
                  : 'No proxy detected — network clear ✅',
              style: TextStyle(
                  color: anyDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(r.detected ? Icons.warning_rounded : Icons.check_circle_rounded,
                    color: r.color, size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(r.check, style: TextStyle(
                    color: r.color, fontSize: 10, fontWeight: FontWeight.w600))),
                Text(r.detail, style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 9)),
              ]))),
        ])),
      const SizedBox(height: ZapSpacing.sm),
      GestureDetector(
        onTap: () {
          ref.read(_proxyTestStateProvider.notifier).state = _ProxyTestState.idle;
          ref.read(_proxyTestResultsProvider.notifier).state = [];
        },
        child: const Text('Run again', style: TextStyle(
            color: Color(0xFF3B82F6), fontSize: 11,
            decoration: TextDecoration.underline))),
    ]);
  }
}

const _kProxyCode = '''
// lib/services/proxy_detector.dart
// 🟢 FRONTEND-ONLY — runs on device

import 'dart:io';

class ProxyDetector {
  /// Returns true if a proxy interceptor is active.
  /// On RELEASE builds, block network if detected.
  static Future<bool> isProxyActive() async {
    // Check 1: HTTP_PROXY environment variable
    final envProxy = Platform.environment['HTTP_PROXY'] ??
                     Platform.environment['HTTPS_PROXY'];
    if (envProxy != null && envProxy.isNotEmpty) return true;

    // Check 2: System proxy via HttpClient
    final client = HttpClient();
    final proxyUri = Uri.parse('https://api.zapsafe.app');
    final proxy = client.findProxyFromEnvironment(proxyUri);
    if (proxy != 'DIRECT') return true;

    // Check 3: Charles default port 8888
    if (await _isPortOpen('127.0.0.1', 8888)) return true;

    // Check 4: Burp Suite default port 8080
    if (await _isPortOpen('127.0.0.1', 8080)) return true;

    return false;
  }

  static Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 200));
      socket.destroy();
      return true;              // port is open — proxy likely running
    } catch (_) {
      return false;             // connection refused — port closed
    }
  }
}

// In main.dart (release builds only):
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kReleaseMode && await ProxyDetector.isProxyActive()) {
    // Show opaque block screen — do not start the app
    runApp(const _ProxyBlockedApp());
    return;
  }

  runApp(const ZapSafeApp());
}''';

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _codeBlock(BuildContext context, String code, Color accentColor) =>
    GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
            duration: Duration(seconds: 1)));
      },
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('long-press to copy',
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
            Icon(Icons.copy_rounded, color: const Color(0xFF4B5563), size: 12),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Text(code, style: TextStyle(color: accentColor.withOpacity(0.9),
              fontSize: 10, fontFamily: 'monospace', height: 1.6)),
        ])));

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
