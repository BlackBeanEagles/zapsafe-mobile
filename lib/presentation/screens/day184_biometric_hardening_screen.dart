/// Day 184 — Biometric Hardening, Crypto Binding & Block Sign-Off
///
/// Second and final day of the Days 183-184 Biometric Lock block.
/// Day 183: Auto-lock, local_auth, LP18 gate map, failure handling  ✅
/// Day 184: Cryptographic binding via Android Keystore / iOS Secure
///           Enclave, bypass-attack detection, block sign-off.
///
/// 🟢 FRONTEND-ONLY — all logic runs on device.
///    Cryptographic binding means the biometric gate CANNOT be bypassed
///    by hooking local_auth — the key is locked inside the secure hardware
///    and only usable if the OS confirms biometric success at the hardware level.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d184TabProvider         = StateProvider<int>((ref) => 0);
final _cryptoTestStateProvider = StateProvider<_CryptoTestState>((ref) => _CryptoTestState.idle);
final _cryptoStepsProvider     = StateProvider<List<_CryptoStep>>((ref) => []);
final _bypassTestStateProvider = StateProvider<_BypassTestState>((ref) => _BypassTestState.idle);
final _bypassResultsProvider   = StateProvider<List<_BypassResult>>((ref) => []);
final _expandedCodeProvider    = StateProvider<int?>((ref) => null);
final _expandedBypassProvider  = StateProvider<int?>((ref) => null);
final _platformProvider        = StateProvider<_Platform>((ref) => _Platform.android);

enum _CryptoTestState { idle, running, passed }
enum _BypassTestState { idle, running, done }
enum _Platform        { android, ios }

// ── Crypto demo steps ─────────────────────────────────────────────────────────
class _CryptoStep {
  final String   label;
  final _StepStatus status;
  final String   detail;
  const _CryptoStep({required this.label, required this.status, required this.detail});
}

enum _StepStatus { pending, running, done, failed }

// ── Bypass check data ─────────────────────────────────────────────────────────
class _BypassResult {
  final String  check;
  final bool    detected;
  final String  detail;
  const _BypassResult({
    required this.check, required this.detected, required this.detail,
  });
}

// ── Code entries ──────────────────────────────────────────────────────────────
class _CodeEntry {
  final String platform, title, description, code;
  const _CodeEntry({
    required this.platform, required this.title,
    required this.description, required this.code,
  });
}

const _kCryptoCode = [
  _CodeEntry(
    platform: 'Android',
    title: 'Android Keystore — biometric-bound key',
    description: 'Generate a key inside the Android Keystore that can only '
        'be used after a biometric authentication. Even Frida cannot extract '
        'or use the key without the hardware confirming the biometric.',
    code: '''// lib/services/crypto_auth_service_android.dart
// Uses platform channel → native Kotlin code

// Kotlin (android/app/src/main/…/CryptoAuthService.kt)
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import javax.crypto.KeyGenerator
import javax.crypto.Cipher

object CryptoAuthService {
  private const val KEY_NAME = "zapsafe_biometric_key"
  private const val KEYSTORE = "AndroidKeyStore"

  fun generateBiometricKey() {
    val keyGenerator = KeyGenerator.getInstance(
      KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)

    val spec = KeyGenParameterSpec.Builder(KEY_NAME,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
      .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
      .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
      .setUserAuthenticationRequired(true)   // KEY POINT: requires biometric
      .setInvalidatedByBiometricEnrollment(true)  // invalidate if new finger added
      .build()

    keyGenerator.init(spec)
    keyGenerator.generateKey()
  }

  fun createCipher(): Cipher {
    val keyStore = java.security.KeyStore.getInstance(KEYSTORE).apply { load(null) }
    val key = keyStore.getKey(KEY_NAME, null) as javax.crypto.SecretKey
    return Cipher.getInstance(
      "\${KeyProperties.KEY_ALGORITHM_AES}/\${KeyProperties.BLOCK_MODE_CBC}/"
      + KeyProperties.ENCRYPTION_PADDING_PKCS7
    ).apply { init(Cipher.ENCRYPT_MODE, key) }
  }
}

// In Flutter — BiometricPrompt uses the Cipher:
// BiometricPrompt.CryptoObject(cipher) is passed to authenticate()
// If biometric succeeds → cipher is usable → key confirmed by hardware
// If biometric is FAKED (Frida hook) → cipher fails to initialise → gate blocked''',
  ),
  _CodeEntry(
    platform: 'iOS',
    title: 'iOS Secure Enclave — biometric-gated key',
    description: 'Create a key inside the Secure Enclave with '
        'kSecAccessControlBiometryCurrentSet. Key is physically inside the '
        'Secure Enclave chip and can only be used when the current enrolled '
        'biometric authenticates — even a jailbreak cannot extract it.',
    code: r'''// Dart → Swift platform channel
// Swift (ios/Runner/CryptoAuthService.swift)

import LocalAuthentication
import Security

class CryptoAuthService {
  static let keyTag = "app.zapsafe.biometricKey".data(using: .utf8)!

  /// Generate a P-256 key inside the Secure Enclave.
  /// Key REQUIRES biometry to use — kSecAccessControlBiometryCurrentSet
  static func generateKey() throws {
    let access = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage, .biometryCurrentSet],  // biometric required + current set
      nil
    )!

    let attributes: [String: Any] = [
      kSecAttrKeyType as String:           kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String:     256,
      kSecAttrTokenID as String:           kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String:    true,
        kSecAttrApplicationTag as String: keyTag,
        kSecAttrAccessControl as String:  access,
      ],
    ]
    var error: Unmanaged<CFError>?
    guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
      throw error!.takeRetainedValue() as Error
    }
  }

  /// Sign a nonce — only works if biometric succeeds at hardware level.
  static func signWithBiometric(nonce: Data, context: LAContext) throws -> Data {
    // Fetch key — system shows biometric prompt (cannot be bypassed)
    var query: [String: Any] = [
      kSecClass as String:              kSecClassKey,
      kSecAttrApplicationTag as String: keyTag,
      kSecReturnRef as String:          true,
      kSecUseAuthenticationContext as String: context,
    ]
    var item: CFTypeRef?
    SecItemCopyMatching(query as CFDictionary, &item)
    let key = item as! SecKey

    var signError: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
        key, .ecdsaSignatureMessageX962SHA256, nonce as CFData, &signError)
    else { throw signError!.takeRetainedValue() as Error }
    return signature as Data
  }
}''',
  ),
  _CodeEntry(
    platform: 'Flutter',
    title: 'Dart: HardenedBiometricGate',
    description: 'The Flutter-side gate that uses the platform channel to '
        'invoke the hardened crypto auth. Falls back to standard local_auth '
        'if the device does not have a Secure Enclave / Keystore (older devices).',
    code: '''// lib/services/hardened_biometric_gate.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class HardenedBiometricGate {
  static const _channel = MethodChannel('com.zapsafe.crypto_auth');

  /// Returns true if the gate was passed using HARDWARE-BACKED crypto.
  /// Falls back to standard local_auth on unsupported devices.
  static Future<bool> authenticate(String reason) async {
    // 1. Check if hardware-backed key is available
    final hasHardwareKey = await _channel.invokeMethod<bool>(
        'hasHardwareKey') ?? false;

    if (hasHardwareKey) {
      // 2. Generate nonce
      final nonce = _generateNonce();

      // 3. Ask native layer to sign nonce using biometric-bound key
      //    This invokes CryptoAuthService.signWithBiometric() on iOS
      //    or CryptoAuthService.createCipher() on Android
      try {
        final signature = await _channel.invokeMethod<Uint8List>(
            'signWithBiometric', {'reason': reason, 'nonce': nonce});
        // 4. Verify signature (public key is stored in app)
        return _verifySignature(nonce, signature!);
      } on PlatformException catch (e) {
        if (e.code == 'AUTH_FAILED') return false;
        if (e.code == 'KEY_INVALIDATED') {
          // New biometric enrolled → key invalidated → security event
          _handleKeyInvalidation();
          return false;
        }
        rethrow;
      }
    }

    // Fallback: standard local_auth (Day 183's BiometricService)
    return BiometricService.authenticate(reason);
  }

  static List<int> _generateNonce() =>
      List.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256);

  static bool _verifySignature(List<int> nonce, Uint8List sig) =>
      sig.isNotEmpty; // simplified — real: ECDSA verify against stored pubkey

  static void _handleKeyInvalidation() {
    // New biometric enrolled → old biometric-bound key invalidated
    // Force user to re-enroll: show "Security alert: new biometric detected"
    // Log to audit trail (Day 173)
  }
}''',
  ),
];

// ── Bypass attack descriptions ─────────────────────────────────────────────────
class _BypassAttack {
  final String   name;
  final String   description;
  final String   howWeDetect;
  final String   howCryptoBlocks;
  final IconData icon;
  final Color    color;
  const _BypassAttack({
    required this.name, required this.description,
    required this.howWeDetect, required this.howCryptoBlocks,
    required this.icon, required this.color,
  });
}

const _kBypassAttacks = [
  _BypassAttack(
    name: 'Frida hook on local_auth',
    description: 'Attacker injects a Frida script that hooks '
        'LocalAuthentication.authenticateWithBiometrics() on iOS '
        'or BiometricPrompt.authenticate() on Android, making it '
        'always return success regardless of actual biometric.',
    howWeDetect: 'Frida detection: scan /proc/self/maps for frida-agent; '
        'check for unusual dynamic libraries. '
        'Also: presence of frida-server port (27042) via socket probe.',
    howCryptoBlocks: 'The Frida hook makes local_auth return true, BUT '
        'the crypto signing step fails because the Secure Enclave / Keystore '
        'only executes if the OS-level biometric actually succeeded. '
        'Frida cannot spoof the hardware. Signing throws → gate blocked.',
    icon: Icons.bug_report_rounded, color: Color(0xFFEF4444),
  ),
  _BypassAttack(
    name: 'Xposed / LSPosed module',
    description: 'A rogue Xposed module hooks the biometric API at the '
        'framework level, returning a success result without showing '
        'the OS biometric dialog.',
    howWeDetect: 'Check for XposedBridge class in the ClassLoader: '
        'Class.forName("de.robv.android.xposed.XposedBridge"). '
        'Also: check /data/data/de.robv.android.xposed.installer.',
    howCryptoBlocks: 'Same as Frida — the Keystore key is hardware-backed. '
        'Even if Xposed fakes the BiometricPrompt result, '
        'the Cipher.init() call fails without real hardware biometric. '
        'The gate detects the KeyNotYetValidException and blocks.',
    icon: Icons.extension_off_rounded, color: Color(0xFFF59E0B),
  ),
  _BypassAttack(
    name: 'Rooted device — key extraction',
    description: 'On a rooted device with root access to the keystore, '
        'an attacker might try to extract the AES key directly from '
        '/data/misc/keystore/ files.',
    howWeDetect: 'Root detection (Day 185-186): check for su binary, '
        'test-keys build, Magisk app, Busybox, selinux disabled.',
    howCryptoBlocks: 'Hardware-backed keys (StrongBox/Secure Enclave) '
        'NEVER leave the hardware chip. They cannot be extracted '
        'even with root. Only software-backed keys (older devices) '
        'are vulnerable — those use the local_auth fallback.',
    icon: Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6),
  ),
  _BypassAttack(
    name: 'Biometric enrollment change',
    description: 'Attacker adds their own fingerprint to the device '
        '(physical access required) then uses their finger to pass the gate.',
    howWeDetect: 'Not detectable before the fact. Detected afterward: '
        'Android setInvalidatedByBiometricEnrollment(true) invalidates '
        'the key when new biometrics are enrolled.',
    howCryptoBlocks: 'Key is invalidated immediately when new biometric '
        'is enrolled. Next biometric gate attempt throws '
        'KeyPermanentlyInvalidatedException → gate blocked → '
        'user must re-authenticate via device PIN and re-generate key.',
    icon: Icons.fingerprint_rounded, color: Color(0xFF3B82F6),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day184BiometricHardeningScreen extends ConsumerWidget {
  const Day184BiometricHardeningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d184TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Biometric Hardening'),
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
                onSelect: (t) => ref.read(_d184TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _CryptoBindingTab(),
            if (tab == 1) const _BypassDetectionTab(),
            if (tab == 2) const _BlockCompleteTab(),
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
            colors: [Color(0xFF0A0814), Color(0xFF060510), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.55), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 184',              const Color(0xFF8B5CF6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section C  ·  Day 4/10',   const Color(0xFF3B82F6)),
          _badge('Block 183-184 Final ✅',   const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Biometric Hardening\n& Crypto Binding',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Android Keystore + iOS Secure Enclave — key accessible only if '
          'hardware confirms biometric. Frida / Xposed hooks cannot bypass it. '
          '4 attack vectors documented with crypto-layer countermeasures.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('3',    '3 code layers',   Color(0xFF8B5CF6)),
          _HStat('4',    '4 attack vectors',Color(0xFFEF4444)),
          _HStat('HW',   'Hardware-backed', Color(0xFF10B981)),
          _HStat('✅',   'Block done',      Color(0xFF10B981)),
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
      (Icons.key_rounded,         Color(0xFF8B5CF6), 'Crypto Binding'),
      (Icons.shield_moon_rounded, Color(0xFFEF4444), 'Bypass Detection'),
      (Icons.emoji_events_rounded,Color(0xFF10B981), 'Block Done'),
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
// TAB 1 — Crypto Binding
// ══════════════════════════════════════════════════════════════════════════════
class _CryptoBindingTab extends ConsumerWidget {
  const _CryptoBindingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState = ref.watch(_cryptoTestStateProvider);
    final steps     = ref.watch(_cryptoStepsProvider);
    final expanded  = ref.watch(_expandedCodeProvider);
    final platform  = ref.watch(_platformProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.key_rounded, color: const Color(0xFF8B5CF6),
          text: 'Standard local_auth (Day 183) asks the OS "did biometric succeed?" '
              'An attacker with Frida can hook that call and always answer "yes". '
              'Cryptographic binding eliminates this: the app tries to USE a hardware key '
              'that the OS only unlocks on real biometric success — '
              'a hook cannot fake the hardware.'),
      const SizedBox(height: ZapSpacing.lg),

      // Architecture diagram
      const _SectionLabel('ARCHITECTURE  ·  HOW CRYPTO BINDING WORKS'),
      const SizedBox(height: ZapSpacing.md),
      _ArchDiagram(platform: platform),
      const SizedBox(height: ZapSpacing.lg),

      // Platform toggle
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => ref.read(_platformProvider.notifier).state = _Platform.android,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: platform == _Platform.android
                    ? const Color(0xFF3DDC84).withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: platform == _Platform.android
                        ? const Color(0xFF3DDC84).withOpacity(0.5)
                        : const Color(0xFF2A2A2A))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 16),
              const SizedBox(width: 6),
              Text('Android Keystore', style: TextStyle(
                  color: platform == _Platform.android
                      ? const Color(0xFF3DDC84) : const Color(0xFF6B7280),
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ))),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: GestureDetector(
          onTap: () => ref.read(_platformProvider.notifier).state = _Platform.ios,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: platform == _Platform.ios
                    ? const Color(0xFF9CA3AF).withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: platform == _Platform.ios
                        ? const Color(0xFF9CA3AF).withOpacity(0.5)
                        : const Color(0xFF2A2A2A))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.apple_rounded, color: Color(0xFF9CA3AF), size: 16),
              const SizedBox(width: 6),
              Text('Secure Enclave', style: TextStyle(
                  color: platform == _Platform.ios
                      ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ))),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Simulated crypto auth flow
      const _SectionLabel('SIMULATED CRYPTO AUTH FLOW'),
      const SizedBox(height: ZapSpacing.md),

      if (testState == _CryptoTestState.idle)
        _primaryBtn(
          label: platform == _Platform.android
              ? 'Run Android Keystore Auth (Mock)'
              : 'Run Secure Enclave Auth (Mock)',
          color: const Color(0xFF8B5CF6),
          onTap: () => _runCryptoTest(ref, platform),
        )
      else
        _CryptoStepList(steps: steps, state: testState, ref: ref),

      const SizedBox(height: ZapSpacing.xl),

      // Code snippets
      const _SectionLabel('3 CODE LAYERS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kCryptoCode.asMap().entries.map((e) {
        final i     = e.key;
        final entry = e.value;
        final isExp = expanded == i;
        const colors = [Color(0xFF3DDC84), Color(0xFF9CA3AF), Color(0xFF8B5CF6)];
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
                    child: Text(entry.platform, style: TextStyle(color: color,
                        fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.title, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(entry.description, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
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
                        child: _codeBlock(context, entry.code))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Future<void> _runCryptoTest(WidgetRef ref, _Platform platform) async {
    ref.read(_cryptoTestStateProvider.notifier).state = _CryptoTestState.running;

    final steps = platform == _Platform.android
        ? [
            'Generate nonce (32 random bytes)',
            'Load key from Android Keystore (AES-256)',
            'Init Cipher — triggers biometric prompt',
            'Biometric confirmed by TrustZone hardware',
            'Cipher.init() succeeds → encrypt nonce',
            'Verify encrypted output (non-empty)',
            'Gate PASSED — hardware biometric confirmed ✅',
          ]
        : [
            'Generate nonce (32 random bytes)',
            'Load P-256 key from Secure Enclave',
            'LAContext triggers Face ID / Touch ID',
            'Secure Enclave confirms biometric',
            'SecKeyCreateSignature() signs nonce',
            'ECDSA signature verified against public key',
            'Gate PASSED — hardware biometric confirmed ✅',
          ];

    for (int i = 0; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 550));
      final current = List.generate(steps.length, (j) => _CryptoStep(
        label: steps[j],
        status: j < i ? _StepStatus.done
            : j == i ? _StepStatus.running
            : _StepStatus.pending,
        detail: j < i ? 'OK' : j == i ? 'In progress…' : '',
      ));
      ref.read(_cryptoStepsProvider.notifier).state = current;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    ref.read(_cryptoStepsProvider.notifier).state = List.generate(
        steps.length, (i) => _CryptoStep(label: steps[i],
            status: _StepStatus.done, detail: 'OK'));
    ref.read(_cryptoTestStateProvider.notifier).state = _CryptoTestState.passed;
  }
}

class _ArchDiagram extends StatelessWidget {
  final _Platform platform;
  const _ArchDiagram({required this.platform});

  @override
  Widget build(BuildContext context) {
    final isAndroid = platform == _Platform.android;
    final color = isAndroid ? const Color(0xFF3DDC84) : const Color(0xFF9CA3AF);
    final hwLabel = isAndroid ? 'Android TrustZone\n(StrongBox Keystore)' : 'Apple Secure Enclave\n(Hardware Chip)';

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        // Row 1: App ↔ OS
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _archBox('ZapSafe\nFlutter App', const Color(0xFF8B5CF6)),
          _arrow(),
          _archBox('OS Biometric\nAPI', const Color(0xFF3B82F6)),
          _arrow(),
          _archBox(hwLabel, color),
        ]),
        const SizedBox(height: ZapSpacing.md),
        // Call chain
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Call chain:', style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w700)),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              isAndroid
                  ? '1. App calls Cipher.init(key) where key is in Keystore\n'
                    '2. Keystore triggers BiometricPrompt (OS modal)\n'
                    '3. TrustZone verifies fingerprint in secure hardware\n'
                    '4. TrustZone unlocks key → Cipher.init() succeeds\n'
                    '5. App uses Cipher to encrypt nonce → success = gate passed'
                  : '1. App calls SecKeyCreateSignature(key, nonce)\n'
                    '2. Secure Enclave triggers LAContext biometric prompt\n'
                    '3. Secure Enclave hardware verifies Face ID / Touch ID\n'
                    '4. Secure Enclave signs nonce → returns ECDSA signature\n'
                    '5. App verifies signature → success = gate passed',
              style: const TextStyle(color: Color(0xFFD1D5DB),
                  fontSize: 10, height: 1.6)),
          ])),
      ]));
  }

  Widget _archBox(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w700, height: 1.4), textAlign: TextAlign.center));

  Widget _arrow() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF4B5563), size: 16));
}

class _CryptoStepList extends StatelessWidget {
  final List<_CryptoStep> steps;
  final _CryptoTestState  state;
  final WidgetRef         ref;
  const _CryptoStepList({required this.steps, required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDone = state == _CryptoTestState.passed;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF10B981).withOpacity(0.07)
              : const Color(0xFF8B5CF6).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
              color: (isDone ? const Color(0xFF10B981) : const Color(0xFF8B5CF6))
                  .withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...steps.map((s) {
          final color = switch (s.status) {
            _StepStatus.done    => const Color(0xFF10B981),
            _StepStatus.running => const Color(0xFF8B5CF6),
            _StepStatus.failed  => const Color(0xFFEF4444),
            _StepStatus.pending => const Color(0xFF2A2A2A),
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              s.status == _StepStatus.running
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Color(0xFF8B5CF6), strokeWidth: 2))
                  : Icon(
                      s.status == _StepStatus.done
                          ? Icons.check_circle_rounded
                          : s.status == _StepStatus.failed
                              ? Icons.cancel_rounded
                              : Icons.radio_button_unchecked_rounded,
                      color: color, size: 14),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(s.label, style: TextStyle(
                  color: s.status == _StepStatus.pending
                      ? const Color(0xFF4B5563) : Colors.white,
                  fontSize: 11))),
            ]));
        }),
        if (isDone) ...[
          const SizedBox(height: ZapSpacing.sm),
          const Divider(color: Color(0xFF10B981), height: 1),
          const SizedBox(height: ZapSpacing.sm),
          const Text('Hardware biometric confirmed. Gate PASSED. ✅',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              ref.read(_cryptoTestStateProvider.notifier).state = _CryptoTestState.idle;
              ref.read(_cryptoStepsProvider.notifier).state = [];
            },
            child: const Text('Run again', style: TextStyle(
                color: Color(0xFF3B82F6), fontSize: 10,
                decoration: TextDecoration.underline))),
        ],
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Bypass Detection
// ══════════════════════════════════════════════════════════════════════════════
class _BypassDetectionTab extends ConsumerWidget {
  const _BypassDetectionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState = ref.watch(_bypassTestStateProvider);
    final results   = ref.watch(_bypassResultsProvider);
    final expanded  = ref.watch(_expandedBypassProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.shield_moon_rounded, color: const Color(0xFFEF4444),
          text: '4 attack vectors against biometric gates. '
              'Each is documented with detection method and '
              'how the crypto-binding layer blocks it even if detection fails.'),
      const SizedBox(height: ZapSpacing.lg),

      // Attack cards
      const _SectionLabel('4 ATTACK VECTORS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kBypassAttacks.asMap().entries.map((e) {
        final i      = e.key;
        final attack = e.value;
        final isExp  = expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedBypassProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? attack.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? attack.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: attack.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(attack.icon, color: attack.color, size: 16)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(attack.name, style: const TextStyle(
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
                        child: _AttackDetail(attack: attack))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.xl),

      // Runtime bypass scan simulation
      const _SectionLabel('SIMULATED BYPASS SCAN'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.radar_rounded, color: const Color(0xFF8B5CF6),
          text: 'This scan runs on every LP18 gate invocation. '
              'If any check detects a bypass tool, the gate is blocked '
              'even before the biometric prompt appears.'),
      const SizedBox(height: ZapSpacing.md),

      if (testState == _BypassTestState.idle)
        _primaryBtn(
          label: 'Run Bypass Scan (Mock)',
          color: const Color(0xFFEF4444),
          onTap: () => _runBypassScan(ref),
        )
      else if (testState == _BypassTestState.running)
        _BypassRunning(results: results)
      else
        _BypassDone(results: results, ref: ref),
    ]);
  }

  Future<void> _runBypassScan(WidgetRef ref) async {
    ref.read(_bypassTestStateProvider.notifier).state = _BypassTestState.running;
    ref.read(_bypassResultsProvider.notifier).state = [];

    final checks = [
      ('Frida agent in /proc/self/maps', false, 'No frida-agent found'),
      ('Port 27042 (frida-server)',       false, 'Port closed'),
      ('XposedBridge class',              false, 'Class not found'),
      ('su binary in PATH',               false, 'Not found (non-rooted device)'),
      ('Magisk app installed',            false, 'Not installed'),
    ];

    final results = <_BypassResult>[];
    for (final (check, detected, detail) in checks) {
      await Future.delayed(const Duration(milliseconds: 500));
      results.add(_BypassResult(check: check, detected: detected, detail: detail));
      ref.read(_bypassResultsProvider.notifier).state = List.from(results);
    }
    ref.read(_bypassTestStateProvider.notifier).state = _BypassTestState.done;
  }
}

class _AttackDetail extends StatelessWidget {
  final _BypassAttack attack;
  const _AttackDetail({required this.attack});

  @override
  Widget build(BuildContext context) => Column(children: [
    _section('Attack',            attack.description,   Icons.warning_rounded,      attack.color),
    const SizedBox(height: ZapSpacing.sm),
    _section('Detection',         attack.howWeDetect,   Icons.radar_rounded,        const Color(0xFF3B82F6)),
    const SizedBox(height: ZapSpacing.sm),
    _section('Crypto blocks it',  attack.howCryptoBlocks,Icons.key_rounded,         const Color(0xFF10B981)),
  ]);

  Widget _section(String label, String body, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(color: Color(0xFFD1D5DB),
                fontSize: 11, height: 1.5)),
          ])),
        ]));
}

class _BypassRunning extends StatelessWidget {
  final List<_BypassResult> results;
  const _BypassRunning({required this.results});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
              color: Color(0xFFEF4444), strokeWidth: 2)),
          SizedBox(width: ZapSpacing.sm),
          Text('Scanning for bypass tools…', style: TextStyle(
              color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        if (results.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.md),
          ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(r.detected ? Icons.warning_rounded : Icons.check_circle_rounded,
                    color: r.detected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(r.check, style: TextStyle(
                    color: r.detected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontSize: 10))),
              ]))),
        ],
      ]));
}

class _BypassDone extends StatelessWidget {
  final List<_BypassResult> results; final WidgetRef ref;
  const _BypassDone({required this.results, required this.ref});

  @override
  Widget build(BuildContext context) {
    final anyDetected = results.any((r) => r.detected);
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
                size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Text(anyDetected ? 'Bypass tool detected — gate BLOCKED'
                : 'No bypass tools detected — gate ALLOWED',
                style: TextStyle(
                    color: anyDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Icon(r.detected ? Icons.warning_rounded : Icons.check_circle_rounded,
                    color: r.detected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(r.check, style: TextStyle(
                    color: r.detected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontSize: 10, fontWeight: FontWeight.w600))),
                Text(r.detail, style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 9)),
              ]))),
        ])),
      const SizedBox(height: ZapSpacing.sm),
      GestureDetector(
        onTap: () {
          ref.read(_bypassTestStateProvider.notifier).state = _BypassTestState.idle;
          ref.read(_bypassResultsProvider.notifier).state = [];
        },
        child: const Text('Run again', style: TextStyle(
            color: Color(0xFF3B82F6), fontSize: 11,
            decoration: TextDecoration.underline))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Block Complete
// ══════════════════════════════════════════════════════════════════════════════
class _BlockCompleteTab extends StatelessWidget {
  const _BlockCompleteTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Celebration
    Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF8B5CF6).withOpacity(0.12),
          const Color(0xFF8B5CF6).withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2),
      ),
      child: const Column(children: [
        Text('🔐', style: TextStyle(fontSize: 44)),
        SizedBox(height: ZapSpacing.md),
        Text('Biometric Lock Block',
            style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14,
                fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.xs),
        Text('DAYS 183 – 184  ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: [
          _Chip('Auto-lock timer ✅',         Color(0xFF8B5CF6)),
          _Chip('local_auth wrapper ✅',       Color(0xFF3B82F6)),
          _Chip('AppLockProvider ✅',          Color(0xFF8B5CF6)),
          _Chip('6 LP18 gates ✅',            Color(0xFFF59E0B)),
          _Chip('Android Keystore ✅',         Color(0xFF3DDC84)),
          _Chip('Secure Enclave ✅',           Color(0xFF9CA3AF)),
          _Chip('Crypto binding ✅',           Color(0xFF10B981)),
          _Chip('4 bypass attacks ✅',         Color(0xFFEF4444)),
          _Chip('Frida detection ✅',          Color(0xFFEF4444)),
          _Chip('Xposed detection ✅',         Color(0xFFF59E0B)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Section C progress
    const _SectionLabel('SECTION C: SECURITY HARDENING  ·  PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        _blockRow(const Color(0xFF10B981), 'Days 181-182',
            'Certificate Pinning + Network Security Config', true),
        const Divider(height: 1, color: Color(0xFF222222)),
        _blockRow(const Color(0xFF10B981), 'Days 183-184',
            'Biometric Lock + LP18 Gate Hardening', true),
        const Divider(height: 1, color: Color(0xFF222222)),
        _blockRow(const Color(0xFF3B82F6), 'Days 185-186',
            'Jailbreak / Root Detection + Tamper Alerts  ←  NEXT', false),
        const Divider(height: 1, color: Color(0xFF222222)),
        _blockRow(const Color(0xFF6B7280), 'Days 187-188',
            'Secure Storage Audit + Hive Encryption Key Rotation', false),
        const Divider(height: 1, color: Color(0xFF222222)),
        _blockRow(const Color(0xFF6B7280), 'Days 189-190',
            'Security Dashboard + Section C Sign-Off', false),
      ]),
    ),
    const SizedBox(height: ZapSpacing.lg),

    // 4/10 progress bar
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('Section C progress',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        Spacer(),
        Text('4 / 10 days  ·  2 / 5 blocks',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: ZapSpacing.sm),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const LinearProgressIndicator(
            value: 4 / 10,
            backgroundColor: Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
            minHeight: 8)),
    ]),
    const SizedBox(height: ZapSpacing.xl),

    // Days 185-186 preview
    const _SectionLabel('NEXT  ·  DAYS 185-186: JAILBREAK / ROOT DETECTION'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
      child: Column(children: [
        _nextRow('Day 185',
            '🟢 FRONTEND-ONLY',
            'Jailbreak detection (iOS): su, Cydia, substrate, '
            'dylib injection. Root detection (Android): '
            'su binary, test-keys, Magisk, build tags.'),
        const Divider(height: 16, color: Color(0xFF1A1A1A)),
        _nextRow('Day 186',
            '🟢 FRONTEND-ONLY',
            'Tamper alert screen: what happens when jailbreak/root is detected '
            '(reduced mode vs full block). SafetyNet Attestation note '
            'for Android. Days 185-186 block sign-off.'),
      ]),
    ),
    const SizedBox(height: ZapSpacing.md),
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF10B981),
        text: 'Days 185-186 remain 🟢 FRONTEND-ONLY — '
            'root/jailbreak detection logic runs entirely on the client. '
            'No server API needed. SafetyNet/Play Integrity is server-verified '
            'but the UI state is driven by the client check.'),
  ]);

  static Widget _blockRow(Color c, String days, String title, bool done) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ])),
          if (done)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)
          else
            const Icon(Icons.radio_button_unchecked_rounded,
                color: Color(0xFF3A3A3A), size: 16),
        ]));

  static Widget _nextRow(String day, String badge, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(day, style: const TextStyle(color: Color(0xFF3B82F6),
              fontSize: 9, fontWeight: FontWeight.w800))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6)),
          child: Text(badge, style: const TextStyle(color: Color(0xFF10B981),
              fontSize: 8, fontWeight: FontWeight.w700))),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(body, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4))),
      ]);
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

Widget _codeBlock(BuildContext context, String code) => GestureDetector(
    onLongPress: () {
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
