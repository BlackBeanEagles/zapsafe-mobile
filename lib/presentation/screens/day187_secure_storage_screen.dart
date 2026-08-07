/// Day 187 — Secure Storage Audit
///
/// First day of the Days 187-188 Secure Storage block.
/// Day 187: Storage audit — Hive vs flutter_secure_storage,
///           data map, AES key in Keychain/Keystore, audit scan.
/// Day 188: Hive AES key rotation — rotate on biometric re-enrol,
///           on demand, and on compromise detection.
///
/// 🟢 FRONTEND-ONLY — all storage runs on-device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d187TabProvider      = StateProvider<int>((ref) => 0);
final _auditStateProvider   = StateProvider<_AuditState>((ref) => _AuditState.idle);
final _auditResultsProvider = StateProvider<List<_AuditResult>>((ref) => []);
final _expandedDataProvider = StateProvider<int?>((ref) => null);
final _expandedCodeProvider = StateProvider<int?>((ref) => null);

enum _AuditState { idle, running, done }

// ── Storage stores ────────────────────────────────────────────────────────────
class _Store {
  final String   name;
  final String   package;
  final String   backingStore;   // what OS storage it uses
  final String   encryption;
  final String   keyStorage;
  final bool     usesByZapSafe;
  final String   usedFor;
  final IconData icon;
  final Color    color;
  final int      securityLevel; // 1-5
  const _Store({
    required this.name, required this.package, required this.backingStore,
    required this.encryption, required this.keyStorage,
    required this.usesByZapSafe, required this.usedFor,
    required this.icon, required this.color, required this.securityLevel,
  });
}

const _kStores = [
  _Store(
    name: 'flutter_secure_storage',
    package: 'flutter_secure_storage: ^9.2.2',
    backingStore: 'iOS Keychain / Android EncryptedSharedPreferences',
    encryption: 'AES-256 (platform-managed)',
    keyStorage: 'Secure Enclave (iOS) / Keystore (Android)',
    usesByZapSafe: true,
    usedFor: 'JWT tokens, Hive AES key, biometric-bound secrets, '
        'duress PIN hash, privacy policy consent versions',
    icon: Icons.lock_rounded,
    color: Color(0xFF10B981),
    securityLevel: 5,
  ),
  _Store(
    name: 'Hive (encrypted)',
    package: 'hive_flutter: ^1.1.0',
    backingStore: 'App documents directory (encrypted .hive file)',
    encryption: 'AES-256-CBC (key from flutter_secure_storage)',
    keyStorage: 'Key stored in flutter_secure_storage (see above)',
    usesByZapSafe: true,
    usedFor: 'Consent records, retention settings, analytics prefs, '
        'notification history, audit log, session config, app state',
    icon: Icons.storage_rounded,
    color: Color(0xFF3B82F6),
    securityLevel: 4,
  ),
  _Store(
    name: 'SharedPreferences',
    package: 'shared_preferences: ^2.3.2',
    backingStore: 'NSUserDefaults (iOS) / SharedPreferences XML (Android)',
    encryption: 'None — plaintext on disk',
    keyStorage: 'N/A — no encryption',
    usesByZapSafe: true,
    usedFor: 'NON-SENSITIVE only: app theme, last-opened screen, '
        'onboarding completion flag, language preference',
    icon: Icons.settings_rounded,
    color: Color(0xFFF59E0B),
    securityLevel: 1,
  ),
  _Store(
    name: 'SQLite (sqflite)',
    package: 'sqflite: ^2.3.3+1',
    backingStore: 'App documents directory (.db file)',
    encryption: 'None (plain sqflite). Encrypted variant: sqlcipher_flutter_libs',
    keyStorage: 'N/A — not currently encrypted by ZapSafe',
    usesByZapSafe: false,
    usedFor: 'NOT used by ZapSafe in current phase. Evidence metadata '
        'considered for Day 187+ but Hive handles current needs.',
    icon: Icons.table_chart_rounded,
    color: Color(0xFF6B7280),
    securityLevel: 2,
  ),
];

// ── Audit checks ─────────────────────────────────────────────────────────────
class _AuditCheck {
  final String   store;
  final String   check;
  final bool     expectedPass;
  final String   passDetail;
  final String   failDetail;
  const _AuditCheck({
    required this.store, required this.check,
    required this.expectedPass, required this.passDetail, required this.failDetail,
  });
}

class _AuditResult {
  final _AuditCheck check;
  final bool   passed;
  const _AuditResult({required this.check, required this.passed});
}

const _kAuditChecks = [
  _AuditCheck(
    store: 'flutter_secure_storage',
    check: 'Keychain/EncryptedSharedPrefs accessible',
    expectedPass: true,
    passDetail: 'flutter_secure_storage read/write successful',
    failDetail: 'Could not access Keychain — check entitlements',
  ),
  _AuditCheck(
    store: 'flutter_secure_storage',
    check: 'JWT token stored (not in SharedPreferences)',
    expectedPass: true,
    passDetail: 'JWT found in secure storage ✅',
    failDetail: 'JWT not in secure storage — potential plaintext leak ⚠',
  ),
  _AuditCheck(
    store: 'flutter_secure_storage',
    check: 'Hive AES key stored securely',
    expectedPass: true,
    passDetail: 'Hive AES-256 key found in Keychain/Keystore ✅',
    failDetail: 'Hive key not in secure storage — Hive data unprotected ⚠',
  ),
  _AuditCheck(
    store: 'Hive (encrypted)',
    check: 'Hive box opened with AES cipher',
    expectedPass: true,
    passDetail: 'All Hive boxes opened with HiveAesCipher ✅',
    failDetail: 'One or more Hive boxes opened without encryption ⚠',
  ),
  _AuditCheck(
    store: 'Hive (encrypted)',
    check: 'No PII in unencrypted Hive box',
    expectedPass: true,
    passDetail: 'PII audit: all PII data is in encrypted boxes ✅',
    failDetail: 'PII detected in unencrypted Hive box ⚠',
  ),
  _AuditCheck(
    store: 'SharedPreferences',
    check: 'No sensitive data in SharedPreferences',
    expectedPass: true,
    passDetail: 'SharedPreferences contains only non-sensitive flags ✅',
    failDetail: 'Sensitive key detected in SharedPreferences ⚠',
  ),
  _AuditCheck(
    store: 'SharedPreferences',
    check: 'No JWT or token in SharedPreferences',
    expectedPass: true,
    passDetail: 'No auth tokens in plaintext storage ✅',
    failDetail: 'AUTH TOKEN FOUND IN PLAINTEXT — critical security issue 🔴',
  ),
  _AuditCheck(
    store: 'General',
    check: 'No plaintext secrets in app bundle',
    expectedPass: true,
    passDetail: 'API keys and secrets not found in app bundle ✅',
    failDetail: 'Potential secret found in assets — review before release ⚠',
  ),
];

// ── Data map entries ──────────────────────────────────────────────────────────
class _DataMapEntry {
  final String   dataType;
  final String   store;
  final String   encryption;
  final int      sensitivity; // 1-5 (5 = most sensitive)
  final String   reason;
  final Color    color;
  const _DataMapEntry({
    required this.dataType, required this.store, required this.encryption,
    required this.sensitivity, required this.reason, required this.color,
  });
}

const _kDataMap = [
  _DataMapEntry(
    dataType: 'JWT auth token',
    store: 'flutter_secure_storage',
    encryption: 'Platform AES-256 (Keychain/Keystore)',
    sensitivity: 5, color: Color(0xFFEF4444),
    reason: 'Compromised JWT = full account takeover. Must be in hardware-backed secure storage.',
  ),
  _DataMapEntry(
    dataType: 'Hive AES encryption key',
    store: 'flutter_secure_storage',
    encryption: 'Platform AES-256 (Keychain/Keystore)',
    sensitivity: 5, color: Color(0xFFEF4444),
    reason: 'This key protects ALL other Hive data. Must never be in plaintext.',
  ),
  _DataMapEntry(
    dataType: 'Duress PIN hash (LP3)',
    store: 'flutter_secure_storage',
    encryption: 'Platform AES-256',
    sensitivity: 5, color: Color(0xFFEF4444),
    reason: 'Knowing the duress PIN = defeating LP3 silent escalation.',
  ),
  _DataMapEntry(
    dataType: 'Vault PIN hash (LP16)',
    store: 'flutter_secure_storage',
    encryption: 'Platform AES-256',
    sensitivity: 5, color: Color(0xFFEF4444),
    reason: 'Evidence Vault PIN protects audio/video evidence.',
  ),
  _DataMapEntry(
    dataType: 'Consent records (DPDP)',
    store: 'Hive (encrypted)',
    encryption: 'Hive AES-256-CBC',
    sensitivity: 3, color: Color(0xFF8B5CF6),
    reason: 'Consent audit trail. Encrypted to prevent tampering evidence.',
  ),
  _DataMapEntry(
    dataType: 'Retention settings',
    store: 'Hive (encrypted)',
    encryption: 'Hive AES-256-CBC',
    sensitivity: 2, color: Color(0xFF3B82F6),
    reason: 'User preferences. Encrypted for consistency; not highly sensitive.',
  ),
  _DataMapEntry(
    dataType: 'Analytics consent flag',
    store: 'Hive (encrypted)',
    encryption: 'Hive AES-256-CBC',
    sensitivity: 2, color: Color(0xFF8B5CF6),
    reason: 'Consent flag must not be tampered. Encrypted Hive prevents modification.',
  ),
  _DataMapEntry(
    dataType: 'App theme / language',
    store: 'SharedPreferences',
    encryption: 'None (plaintext)',
    sensitivity: 1, color: Color(0xFF6B7280),
    reason: 'Not sensitive. SharedPreferences is fine — no PII, no security impact.',
  ),
  _DataMapEntry(
    dataType: 'Onboarding completion flag',
    store: 'SharedPreferences',
    encryption: 'None (plaintext)',
    sensitivity: 1, color: Color(0xFF6B7280),
    reason: 'Low sensitivity. Worst case: attacker resets onboarding flag. No data leak.',
  ),
  _DataMapEntry(
    dataType: 'Last-seen screen / route',
    store: 'SharedPreferences',
    encryption: 'None (plaintext)',
    sensitivity: 1, color: Color(0xFF6B7280),
    reason: 'UI state only. No security impact if visible.',
  ),
];

// ── Code snippets ─────────────────────────────────────────────────────────────
class _CodeSnippet {
  final String title, subtitle, code;
  const _CodeSnippet({required this.title, required this.subtitle, required this.code});
}

const _kCodeSnippets = [
  _CodeSnippet(
    title: 'Encrypted Hive initialisation',
    subtitle: 'Retrieve key from Keychain/Keystore → open all boxes with cipher',
    code: '''// lib/services/storage_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _keyName = 'zapsafe_hive_aes_key';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Call once in main() before opening any Hive box.
  static Future<HiveAesCipher> getOrCreateHiveCipher() async {
    // 1. Try to load existing key from Keychain/Keystore
    String? keyHex = await _secureStorage.read(key: _keyName);

    if (keyHex == null) {
      // 2. First launch — generate a new 256-bit AES key
      final key = Hive.generateSecureKey();            // List<int>, 32 bytes
      keyHex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      // 3. Store key in platform Keychain / Android Keystore
      await _secureStorage.write(key: _keyName, value: keyHex);
    }

    // 4. Decode hex → bytes → cipher
    final keyBytes = List<int>.generate(32, (i) =>
        int.parse(keyHex!.substring(i * 2, i * 2 + 2), radix: 16));
    return HiveAesCipher(keyBytes);
  }
}

// In main.dart:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final cipher = await StorageService.getOrCreateHiveCipher();

  // All sensitive boxes opened with cipher:
  await Hive.openBox<dynamic>('consent_records',     encryptionCipher: cipher);
  await Hive.openBox<dynamic>('retention_settings',  encryptionCipher: cipher);
  await Hive.openBox<dynamic>('analytics_prefs',     encryptionCipher: cipher);

  // Non-sensitive boxes opened WITHOUT cipher (SharedPreferences alternative):
  await Hive.openBox<dynamic>('app_ui_prefs');  // theme, language, onboarding

  runApp(const ProviderScope(child: ZapSafeApp()));
}''',
  ),
  _CodeSnippet(
    title: 'JWT storage (flutter_secure_storage)',
    subtitle: 'Store and retrieve JWT from Keychain — never SharedPreferences',
    code: '''// lib/services/token_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _accessTokenKey  = 'zapsafe_access_token';
  static const _refreshTokenKey = 'zapsafe_refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey,  value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  // ⚠️  NEVER do this:
  // SharedPreferences.setString('token', accessToken);  // PLAINTEXT ON DISK
}''',
  ),
  _CodeSnippet(
    title: 'Storage audit helper',
    subtitle: 'Runtime check that verifies all sensitive data is in secure stores',
    code: '''// lib/services/storage_auditor.dart

class StorageAuditor {
  /// Run on debug builds and after security events.
  /// Returns a list of violations for Sentry reporting.
  static Future<List<String>> runAudit() async {
    final violations = <String>[];

    // Check 1: JWT in secure storage, not SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['token', 'accessToken', 'jwt', 'auth_token']) {
      if (prefs.containsKey(key)) {
        violations.add('CRITICAL: Auth token found in SharedPreferences key: \$key');
      }
    }

    // Check 2: Hive AES key in secure storage
    const ss = FlutterSecureStorage();
    final hiveKey = await ss.read(key: 'zapsafe_hive_aes_key');
    if (hiveKey == null) {
      violations.add('WARNING: Hive AES key not found — boxes may be unencrypted');
    }

    // Check 3: No sensitive Hive box opened without cipher
    // (checked by verifying box.isEncrypted at runtime)
    if (Hive.isBoxOpen('consent_records') &&
        !Hive.box('consent_records').isEncrypted) {
      violations.add('WARNING: consent_records box opened without cipher');
    }

    return violations;
  }
}''',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day187SecureStorageScreen extends ConsumerWidget {
  const Day187SecureStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d187TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Secure Storage Audit'),
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
                onSelect: (t) => ref.read(_d187TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _AuditTab(),
            if (tab == 1) const _DataMapTab(),
            if (tab == 2) const _ImplementationTab(),
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
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF081008), Color(0xFF050805), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 187',              const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section C  ·  Day 7/10',   const Color(0xFF3B82F6)),
          _badge('Secure Storage  ·  Day 1/2',const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Secure Storage\nAudit',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '4 storage stores mapped. '
          'flutter_secure_storage (level 5) + Hive AES-256 (level 4) '
          'for sensitive data. SharedPreferences for non-sensitive only. '
          '8-point audit scan + 10-item data map.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('4',  '4 stores mapped', Color(0xFF10B981)),
          _HStat('8',  '8 audit checks',  Color(0xFF3B82F6)),
          _HStat('10', '10 data types',   Color(0xFF8B5CF6)),
          _HStat('3',  '3 code snippets', Color(0xFFF59E0B)),
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
      (Icons.security_rounded,   Color(0xFF10B981), 'Audit Scan'),
      (Icons.map_rounded,        Color(0xFF8B5CF6), 'Data Map'),
      (Icons.code_rounded,       Color(0xFFF59E0B), 'Implementation'),
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
// TAB 1 — Audit Scan
// ══════════════════════════════════════════════════════════════════════════════
class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditState  = ref.watch(_auditStateProvider);
    final results     = ref.watch(_auditResultsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.security_rounded, color: const Color(0xFF10B981),
          text: 'Verifies ZapSafe uses the correct storage tier '
              'for each type of data. Run on every debug build. '
              'Critical violations → Sentry alert + block app start.'),
      const SizedBox(height: ZapSpacing.lg),

      // Storage stores overview
      const _SectionLabel('4 STORAGE STORES  ·  SECURITY LEVELS'),
      const SizedBox(height: ZapSpacing.md),
      ..._kStores.map((s) => _StoreCard(store: s)),
      const SizedBox(height: ZapSpacing.xl),

      // Audit scan
      const _SectionLabel('8-POINT AUDIT SCAN'),
      const SizedBox(height: ZapSpacing.md),
      if (auditState == _AuditState.idle)
        _primaryBtn(
          label: 'Run Storage Audit (Mock)',
          color: const Color(0xFF10B981),
          onTap: () => _runAudit(ref),
        )
      else
        _AuditResults(state: auditState, results: results, allChecks: _kAuditChecks, ref: ref),
    ]);
  }

  Future<void> _runAudit(WidgetRef ref) async {
    ref.read(_auditStateProvider.notifier).state = _AuditState.running;
    ref.read(_auditResultsProvider.notifier).state = [];
    final list = <_AuditResult>[];
    for (final check in _kAuditChecks) {
      await Future.delayed(const Duration(milliseconds: 320));
      list.add(_AuditResult(check: check, passed: check.expectedPass));
      ref.read(_auditResultsProvider.notifier).state = List.from(list);
    }
    ref.read(_auditStateProvider.notifier).state = _AuditState.done;
  }
}

class _StoreCard extends StatelessWidget {
  final _Store store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: store.usesByZapSafe
              ? store.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
              color: store.usesByZapSafe
                  ? store.color.withOpacity(0.35) : const Color(0xFF2A2A2A),
              width: store.usesByZapSafe ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(
                  color: store.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(store.icon, color: store.color, size: 17)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(store.name, style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700)),
            Text(store.package, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 9, fontFamily: 'monospace')),
          ])),
          // Security level
          Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) =>
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                      color: i < store.securityLevel ? store.color : const Color(0xFF2A2A2A),
                      shape: BoxShape.circle)))),
            Text('Level ${store.securityLevel}/5',
                style: TextStyle(color: store.color, fontSize: 8, fontWeight: FontWeight.w700)),
          ]),
          if (!store.usesByZapSafe) ...[
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(6)),
              child: const Text('Not used', style: TextStyle(
                  color: Color(0xFF4B5563), fontSize: 8))),
          ],
        ]),
        const SizedBox(height: ZapSpacing.sm),
        _infoRow('Backing', store.backingStore, store.color),
        const SizedBox(height: ZapSpacing.xs),
        _infoRow('Encryption', store.encryption, store.color),
        const SizedBox(height: ZapSpacing.xs),
        _infoRow('Key storage', store.keyStorage, store.color),
        if (store.usesByZapSafe) ...[
          const SizedBox(height: ZapSpacing.xs),
          _infoRow('Used for', store.usedFor, store.color),
        ],
      ]));

  Widget _infoRow(String k, String v, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 76, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
      ]);
}

class _AuditResults extends StatelessWidget {
  final _AuditState state; final List<_AuditResult> results;
  final List<_AuditCheck> allChecks; final WidgetRef ref;
  const _AuditResults({required this.state, required this.results,
      required this.allChecks, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isRunning = state == _AuditState.running;
    final passCount = results.where((r) => r.passed).length;
    final failCount = results.where((r) => !r.passed).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: (failCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                .withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: (failCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                    .withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            isRunning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                    color: Color(0xFF10B981), strokeWidth: 2))
                : Icon(failCount > 0 ? Icons.warning_rounded : Icons.verified_rounded,
                    color: failCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(isRunning ? 'Auditing storage…'
                : failCount > 0 ? '$failCount issue${failCount == 1 ? "" : "s"} found'
                : 'All $passCount checks passed ✅',
                style: TextStyle(
                    color: failCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          if (!isRunning && results.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: passCount / allChecks.length,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(
                        failCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                    minHeight: 5)),
          ],
        ])),
      const SizedBox(height: ZapSpacing.md),

      // Result rows
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          ...results.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final color = r.passed ? const Color(0xFF10B981) : const Color(0xFFEF4444);
            final isLast = i == results.length - 1 && !isRunning;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(6)),
                    child: Text(r.check.store, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 8))),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.check.check, style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
                    Text(r.passed ? r.check.passDetail : r.check.failDetail,
                        style: TextStyle(color: color, fontSize: 9, height: 1.3)),
                  ])),
                  Icon(r.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: color, size: 14),
                ])),
              if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
          // Pending
          if (isRunning)
            ...allChecks.skip(results.length).map((c) => Column(children: [
              const Divider(height: 1, color: Color(0xFF1E1E1E)),
              Padding(padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(c.store, style: const TextStyle(
                            color: Color(0xFF2A2A2A), fontSize: 8))),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(child: Text(c.check, style: const TextStyle(
                        color: Color(0xFF3A3A3A), fontSize: 11))),
                  ])),
            ])),
        ])),

      if (!isRunning) ...[
        const SizedBox(height: ZapSpacing.sm),
        GestureDetector(
          onTap: () {
            ref.read(_auditStateProvider.notifier).state = _AuditState.idle;
            ref.read(_auditResultsProvider.notifier).state = [];
          },
          child: const Text('Run again', style: TextStyle(
              color: Color(0xFF3B82F6), fontSize: 11,
              decoration: TextDecoration.underline))),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Data Map
// ══════════════════════════════════════════════════════════════════════════════
class _DataMapTab extends ConsumerWidget {
  const _DataMapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedDataProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.map_rounded, color: const Color(0xFF8B5CF6),
          text: '10 data types mapped to their storage location. '
              'Sensitivity 1 (low) to 5 (critical). '
              'Tap any row to see why that storage was chosen.'),
      const SizedBox(height: ZapSpacing.lg),

      // Sensitivity legend
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _leg(const Color(0xFFEF4444), '5 — Critical'),
          _leg(const Color(0xFFF59E0B), '4 — High'),
          _leg(const Color(0xFF8B5CF6), '3 — Medium'),
          _leg(const Color(0xFF3B82F6), '2 — Low'),
          _leg(const Color(0xFF6B7280), '1 — Minimal'),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Table header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
        decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ZapSpacing.radiusSmall),
                topRight: Radius.circular(ZapSpacing.radiusSmall))),
        child: const Row(children: [
          Expanded(flex: 3, child: Text('Data type',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                  fontWeight: FontWeight.w700))),
          Expanded(flex: 2, child: Text('Store',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                  fontWeight: FontWeight.w700))),
          SizedBox(width: 36, child: Text('Sens.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                  fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
        ])),

      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(ZapSpacing.radiusSmall),
                bottomRight: Radius.circular(ZapSpacing.radiusSmall)),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: _kDataMap.asMap().entries.map((e) {
          final i     = e.key;
          final entry = e.value;
          final isExp = expanded == i;
          final isLast= i == _kDataMap.length - 1;
          return Column(children: [
            GestureDetector(
              onTap: () => ref.read(_expandedDataProvider.notifier).state =
                  isExp ? null : i,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                color: isExp ? entry.color.withOpacity(0.06) : Colors.transparent,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(entry.dataType,
                          style: const TextStyle(color: Colors.white, fontSize: 11))),
                      Expanded(flex: 2, child: Text(
                          entry.store.split(' ').first,
                          style: TextStyle(color: entry.color, fontSize: 9,
                              fontWeight: FontWeight.w600))),
                      SizedBox(width: 36, child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (j) => Container(
                              width: 5, height: 5, margin: const EdgeInsets.only(right: 1),
                              decoration: BoxDecoration(
                                  color: j < entry.sensitivity
                                      ? entry.color : const Color(0xFF2A2A2A),
                                  shape: BoxShape.circle))))),
                    ])),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: isExp
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                                ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                            child: Container(
                              padding: const EdgeInsets.all(ZapSpacing.sm),
                              decoration: BoxDecoration(
                                  color: entry.color.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                  border: Border.all(color: entry.color.withOpacity(0.25))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                _kv('Store',      entry.store),
                                _kv('Encryption', entry.encryption),
                                _kv('Why',        entry.reason),
                              ])))
                        : const SizedBox.shrink(),
                  ),
                ]),
              )),
            if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
          ]);
        }).toList()),
      ),
    ]);
  }

  Widget _leg(Color c, String l) => Expanded(child: Column(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(height: 3),
    Text(l, style: TextStyle(color: c, fontSize: 7, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center),
  ]));

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 68, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Implementation
// ══════════════════════════════════════════════════════════════════════════════
class _ImplementationTab extends ConsumerWidget {
  const _ImplementationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedCodeProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFFF59E0B),
          text: '3 code snippets: encrypted Hive initialisation, '
              'JWT storage in flutter_secure_storage, '
              'and the storage auditor helper class.'),
      const SizedBox(height: ZapSpacing.lg),

      ..._kCodeSnippets.asMap().entries.map((e) {
        final i      = e.key;
        final snippet= e.value;
        final isExp  = expanded == i;
        const colors = [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFF8B5CF6)];
        final color  = colors[i];

        return GestureDetector(
          onTap: () => ref.read(_expandedCodeProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('DART', style: TextStyle(color: color,
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(snippet.title, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(snippet.subtitle, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ])),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _codeBlock(context, snippet.code))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF8B5CF6),
          text: 'Day 188 builds Hive AES key rotation: '
              'when biometric changes (LP183-184 invalidation), '
              're-encrypt all Hive boxes under a new key. '
              'Includes a "manual rotate" button and rotation history log.'),
    ]);
  }
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

Widget _codeBlock(BuildContext context, String code) => GestureDetector(
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
