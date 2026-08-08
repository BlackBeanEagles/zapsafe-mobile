/// Day 188 — Hive AES Key Rotation & Block Sign-Off
///
/// Second and final day of the Days 187-188 Secure Storage block.
/// Day 187: Storage audit — stores, data map, audit scan           ✅
/// Day 188: Hive AES key rotation — 3 triggers, animated pipeline,
///           rotation history log, block sign-off.
///
/// 🟢 FRONTEND-ONLY — key rotation runs entirely on-device.
///    New AES key generated → stored in Keychain/Keystore →
///    all encrypted Hive boxes re-encrypted → old key wiped.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d188TabProvider        = StateProvider<int>((ref) => 0);
final _rotationStateProvider  = StateProvider<_RotState>((ref) => _RotState.idle);
final _rotationStepsProvider  = StateProvider<List<_RotStep>>((ref) => []);
final _triggerProvider        = StateProvider<_Trigger?>((ref) => null);
final _expandedCodeProvider   = StateProvider<int?>((ref) => null);
final _expandedHistProvider   = StateProvider<int?>((ref) => null);

enum _RotState  { idle, rotating, done }
enum _Trigger   { biometricChange, manual, compromise }

// ── Rotation step model ───────────────────────────────────────────────────────
class _RotStep {
  final String   label;
  final _StepSt  status;
  final String   detail;
  const _RotStep({required this.label, required this.status, required this.detail});
}
enum _StepSt { pending, running, done, error }

// ── History entries ───────────────────────────────────────────────────────────
class _HistoryEntry {
  final DateTime ts;
  final _Trigger trigger;
  final String   result;
  final String   detail;
  const _HistoryEntry({
    required this.ts, required this.trigger,
    required this.result, required this.detail,
  });
}

final _kHistory = [
  _HistoryEntry(
    ts: DateTime(2026, 5, 28, 10, 13),
    trigger: _Trigger.biometricChange,
    result: 'Success',
    detail: 'New fingerprint enrolled on Samsung Galaxy S24. '
        'Key invalidated by Android Keystore. '
        'Rotation: 4 boxes re-encrypted in 1.2 seconds.',
  ),
  _HistoryEntry(
    ts: DateTime(2026, 3, 15, 9, 02),
    trigger: _Trigger.manual,
    result: 'Success',
    detail: 'User-initiated rotation via Settings → Security. '
        'Reason: precautionary after device shared with family member. '
        'Rotation: 4 boxes re-encrypted in 0.9 seconds.',
  ),
  _HistoryEntry(
    ts: DateTime(2026, 1, 15, 9, 01),
    trigger: _Trigger.manual,
    result: 'Success',
    detail: 'First key generation at account setup. '
        'No previous key to rotate from. '
        '4 boxes initialised with new cipher.',
  ),
];

// ── Hive boxes rotated ────────────────────────────────────────────────────────
const _kBoxes = [
  ('consent_records',   'Consent records (DPDP)',      Color(0xFF8B5CF6)),
  ('retention_settings','Retention settings',           Color(0xFF3B82F6)),
  ('analytics_prefs',   'Analytics preferences',        Color(0xFF8B5CF6)),
  ('app_state',         'App state / session config',   Color(0xFF6B7280)),
];

// ── Trigger config ────────────────────────────────────────────────────────────
const _triggerInfo = {
  _Trigger.biometricChange: (
    'New biometric enrolled',
    Color(0xFFF59E0B),
    Icons.fingerprint_rounded,
    'A new finger or face was added to the device. '
        'The old hardware-bound Hive key (tied to previous biometric set) '
        'was automatically invalidated by the Android Keystore / Secure Enclave. '
        'ZapSafe detects this via KeyPermanentlyInvalidatedException (Day 184) '
        'and triggers rotation immediately.',
  ),
  _Trigger.manual: (
    'Manual rotation',
    Color(0xFF3B82F6),
    Icons.refresh_rounded,
    'User manually requests key rotation via Settings → Security. '
        'Useful after: sharing device temporarily, suspicion of key compromise, '
        'or as a periodic security hygiene measure. '
        'ZapSafe asks for biometric/PIN confirmation (LP18) before rotating.',
  ),
  _Trigger.compromise: (
    'Compromise detected',
    Color(0xFFEF4444),
    Icons.warning_rounded,
    'Day 185-186 root/jailbreak detection flagged the device. '
        'ZapSafe cannot guarantee Keychain/Keystore integrity on a compromised device, '
        'so it forces a key rotation AND reduces to Safe Mode. '
        'The new key is generated and stored, but the user is warned '
        'the device remains at risk until cleaned.',
  ),
};

// ── Code snippets ─────────────────────────────────────────────────────────────
class _CodeSnippet {
  final String title, subtitle, code;
  const _CodeSnippet({required this.title, required this.subtitle, required this.code});
}

const _kSnippets = [
  _CodeSnippet(
    title: 'HiveKeyRotationService',
    subtitle: 'Full rotation: generate → store → re-encrypt → wipe old key',
    code: '''// lib/services/hive_key_rotation_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HiveKeyRotationService {
  static const _keyName    = 'zapsafe_hive_aes_key';
  static const _oldKeyName = 'zapsafe_hive_aes_key_old';
  static const _storage    = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Hive boxes that contain encrypted data
  static const _boxNames = [
    'consent_records', 'retention_settings',
    'analytics_prefs', 'app_state',
  ];

  /// Rotate the AES key and re-encrypt all Hive boxes.
  /// Call when:
  ///   1. Biometric re-enrollment detected (KeyPermanentlyInvalidatedException)
  ///   2. User manually requests rotation (Settings → Security)
  ///   3. Compromise detected (Day 185-186)
  static Future<void> rotate(RotationTrigger trigger) async {
    // 1. Read current key
    final oldKeyHex = await _storage.read(key: _keyName);
    if (oldKeyHex == null) throw StateError('No existing key to rotate');

    // 2. Back up old key temporarily (in case re-encrypt fails)
    await _storage.write(key: _oldKeyName, value: oldKeyHex);

    try {
      // 3. Generate new 256-bit AES key
      final newKey    = Hive.generateSecureKey();
      final newKeyHex = newKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final newCipher = HiveAesCipher(newKey);

      // 4. Re-encrypt each box under the new key
      final oldBytes  = List<int>.generate(32, (i) =>
          int.parse(oldKeyHex.substring(i * 2, i * 2 + 2), radix: 16));
      final oldCipher = HiveAesCipher(oldBytes);

      for (final boxName in _boxNames) {
        await _reEncryptBox(boxName, oldCipher, newCipher);
      }

      // 5. Store new key in Keychain/Keystore — overwrites old
      await _storage.write(key: _keyName, value: newKeyHex);

      // 6. Wipe backup key
      await _storage.delete(key: _oldKeyName);

      // 7. Log to audit trail (Day 173)
      _logRotation(trigger, success: true);

    } catch (e) {
      // Restore from backup if re-encrypt failed mid-way
      final backup = await _storage.read(key: _oldKeyName);
      if (backup != null) {
        await _storage.write(key: _keyName, value: backup);
        await _storage.delete(key: _oldKeyName);
      }
      _logRotation(trigger, success: false, error: e.toString());
      rethrow;
    }
  }

  static Future<void> _reEncryptBox(
      String name, HiveAesCipher oldCipher, HiveAesCipher newCipher) async {
    // 1. Open with old cipher → read all data
    final oldBox = await Hive.openBox<dynamic>(name, encryptionCipher: oldCipher);
    final snapshot = Map<dynamic, dynamic>.from(oldBox.toMap());
    await oldBox.close();

    // 2. Delete old encrypted file
    await Hive.deleteBoxFromDisk(name);

    // 3. Re-open with new cipher → write all data back
    final newBox = await Hive.openBox<dynamic>(name, encryptionCipher: newCipher);
    await newBox.putAll(snapshot);
    await newBox.close();
  }

  static void _logRotation(RotationTrigger trigger, {
    required bool success, String? error,
  }) {
    // Append to audit log (Day 173 AuditLogger)
    // Fields: timestamp, trigger, success, error?
  }
}''',
  ),
  _CodeSnippet(
    title: 'Biometric-change detection → auto-rotate',
    subtitle: 'Handle KeyPermanentlyInvalidatedException from Day 184',
    code: '''// lib/services/hardened_biometric_gate.dart (Day 184)
// Add rotation trigger on KeyPermanentlyInvalidatedException

static Future<bool> authenticate(String reason) async {
  try {
    final signature = await _channel.invokeMethod<Uint8List>(
        'signWithBiometric', {'reason': reason, 'nonce': _generateNonce()});
    return _verifySignature(_generateNonce(), signature!);

  } on PlatformException catch (e) {

    if (e.code == 'KEY_INVALIDATED') {
      // New biometric was enrolled → hardware key invalidated
      // 1. Show "New biometric detected" dialog (LP183-184)
      // 2. Trigger Hive key rotation
      await HiveKeyRotationService.rotate(RotationTrigger.biometricChange);
      // 3. Return false — user must re-authenticate with new biometric
      return false;
    }

    if (e.code == 'AUTH_FAILED') return false;
    rethrow;
  }
}''',
  ),
  _CodeSnippet(
    title: 'Manual rotation UI hook',
    subtitle: 'Settings → Security → Rotate Storage Key (LP18 gated)',
    code: '''// In Settings → Security screen:

ElevatedButton(
  onPressed: () async {
    // 1. LP18 gate — require biometric before rotation
    final authed = await HardenedBiometricGate.authenticate(
        "Verify identity to rotate storage key");
    if (!authed) return;

    // 2. Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rotate encryption key?"),
        content: const Text(
            "This will re-encrypt all your local data under a new key. "
            "The app will be unavailable for ~2 seconds."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text("Rotate", style: TextStyle(color: Colors.red))),
        ],
      ));

    if (confirmed != true) return;

    // 3. Show rotating indicator — block UI
    setState(() => _isRotating = true);
    try {
      await HiveKeyRotationService.rotate(RotationTrigger.manual);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Encryption key rotated ✅")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rotation failed: \$e")));
    } finally {
      setState(() => _isRotating = false);
    }
  },
  child: const Text("Rotate Storage Key"),
)''',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day188KeyRotationScreen extends ConsumerWidget {
  const Day188KeyRotationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d188TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Hive Key Rotation'),
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
                onSelect: (t) => ref.read(_d188TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _RotationTab(),
            if (tab == 1) const _ImplementationTab(),
            if (tab == 2) const _BlockCompleteTab(),
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
          _badge('⚡  DAY 188',              const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section C  ·  Day 8/10',   const Color(0xFF3B82F6)),
          _badge('Block 187-188 Final ✅',   const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Hive AES Key\nRotation',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '3 rotation triggers: biometric change (auto), manual, '
          'compromise detected. Animated 7-step pipeline. '
          'Full Dart code. Rotation history log.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('3',  '3 triggers',       Color(0xFF10B981)),
          _HStat('4',  '4 boxes rotated',  Color(0xFF3B82F6)),
          _HStat('7',  '7 pipeline steps', Color(0xFF8B5CF6)),
          _HStat('3',  '3 history entries',Color(0xFFF59E0B)),
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
      (Icons.refresh_rounded,      Color(0xFF10B981), 'Rotation Demo'),
      (Icons.code_rounded,         Color(0xFF3B82F6), 'Implementation'),
      (Icons.emoji_events_rounded, Color(0xFF10B981), 'Block Done'),
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
// TAB 1 — Rotation Demo
// ══════════════════════════════════════════════════════════════════════════════
class _RotationTab extends ConsumerWidget {
  const _RotationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(_rotationStateProvider);
    final steps    = ref.watch(_rotationStepsProvider);
    final trigger  = ref.watch(_triggerProvider);
    final expanded = ref.watch(_expandedHistProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.refresh_rounded, color: const Color(0xFF10B981),
          text: 'Key rotation replaces the Hive AES-256 key, '
              're-encrypts all 4 Hive boxes under the new key, '
              'and wipes the old key. Takes ~1-2 seconds on device.'),
      const SizedBox(height: ZapSpacing.lg),

      // Trigger selector
      const _SectionLabel('SELECT ROTATION TRIGGER'),
      const SizedBox(height: ZapSpacing.md),
      Column(children: _Trigger.values.map((t) {
        final (label, color, icon, detail) = _triggerInfo[t]!;
        final isActive = trigger == t;
        return GestureDetector(
          onTap: () {
            ref.read(_triggerProvider.notifier).state = t;
            if (state != _RotState.idle) {
              ref.read(_rotationStateProvider.notifier).state = _RotState.idle;
              ref.read(_rotationStepsProvider.notifier).state = [];
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.08) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: isActive ? 2 : 1)),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: isActive ? color : Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                Text(detail, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
                    height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
              if (isActive)
                Icon(Icons.check_circle_rounded, color: color, size: 18),
            ]),
          ),
        );
      }).toList()),
      const SizedBox(height: ZapSpacing.xl),

      // Pipeline / button
      const _SectionLabel('7-STEP ROTATION PIPELINE'),
      const SizedBox(height: ZapSpacing.md),

      if (state == _RotState.idle)
        _primaryBtn(
          label: trigger == null
              ? 'Select a trigger above first'
              : 'Run Key Rotation  (${_triggerInfo[trigger]!.$1})',
          color: trigger == null ? const Color(0xFF2A2A2A) : const Color(0xFF10B981),
          onTap: trigger == null ? null : () => _rotate(ref, trigger),
        )
      else
        _PipelineCard(steps: steps, state: state, ref: ref),

      const SizedBox(height: ZapSpacing.xl),

      // Rotation history
      const _SectionLabel('ROTATION HISTORY  ·  3 ENTRIES'),
      const SizedBox(height: ZapSpacing.md),
      ..._kHistory.asMap().entries.map((e) {
        final i    = e.key;
        final hist = e.value;
        final isExp= expanded == i;
        final (label, color, icon, _) = _triggerInfo[hist.trigger]!;
        return GestureDetector(
          onTap: () => ref.read(_expandedHistProvider.notifier).state =
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
                  Icon(icon, color: color, size: 15),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(_fmtDate(hist.ts), style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(hist.result, style: const TextStyle(
                        color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w700))),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ])),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Text(hist.detail, style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6))))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Future<void> _rotate(WidgetRef ref, _Trigger trigger) async {
    ref.read(_rotationStateProvider.notifier).state = _RotState.rotating;

    final stepLabels = [
      'Read current AES key from Keychain/Keystore',
      'Back up old key (crash safety)',
      'Generate new 256-bit AES key  (Hive.generateSecureKey)',
      ..._kBoxes.map((b) => 'Re-encrypt "${b.$1}" box'),
      'Store new key in Keychain/Keystore',
      'Wipe backup key + log rotation',
    ];

    for (int i = 0; i < stepLabels.length; i++) {
      await Future.delayed(const Duration(milliseconds: 480));
      ref.read(_rotationStepsProvider.notifier).state =
          List.generate(stepLabels.length, (j) => _RotStep(
            label: stepLabels[j],
            status: j < i ? _StepSt.done
                : j == i ? _StepSt.running : _StepSt.pending,
            detail: j < i ? 'OK' : '',
          ));
    }

    await Future.delayed(const Duration(milliseconds: 300));
    ref.read(_rotationStepsProvider.notifier).state =
        stepLabels.map((l) => _RotStep(
            label: l, status: _StepSt.done, detail: 'OK')).toList();
    ref.read(_rotationStateProvider.notifier).state = _RotState.done;
  }

  static String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
}

class _PipelineCard extends StatelessWidget {
  final List<_RotStep> steps; final _RotState state; final WidgetRef ref;
  const _PipelineCard({required this.steps, required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDone = state == _RotState.done;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF10B981).withOpacity(0.07)
              : const Color(0xFF10B981).withOpacity(0.04),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          isDone
              ? const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18)
              : const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Color(0xFF10B981), strokeWidth: 2)),
          const SizedBox(width: ZapSpacing.sm),
          Text(isDone ? 'Key rotation complete ✅' : 'Rotating encryption key…',
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        ...steps.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            switch (s.status) {
              _StepSt.done    => const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 14),
              _StepSt.running => const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      color: Color(0xFF10B981), strokeWidth: 2)),
              _StepSt.error   => const Icon(Icons.cancel_rounded,
                  color: Color(0xFFEF4444), size: 14),
              _StepSt.pending => const Icon(Icons.radio_button_unchecked_rounded,
                  color: Color(0xFF2A2A2A), size: 14),
            },
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(s.label, style: TextStyle(
                color: s.status == _StepSt.pending
                    ? const Color(0xFF4B5563) : Colors.white,
                fontSize: 11))),
          ]))),
        if (isDone) ...[
          const SizedBox(height: ZapSpacing.sm),
          const Divider(color: Color(0xFF10B981), height: 1),
          const SizedBox(height: ZapSpacing.sm),
          const Text('All 4 boxes re-encrypted under new key. Old key wiped.',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              ref.read(_rotationStateProvider.notifier).state = _RotState.idle;
              ref.read(_rotationStepsProvider.notifier).state = [];
            },
            child: const Text('Run again', style: TextStyle(
                color: Color(0xFF3B82F6), fontSize: 10,
                decoration: TextDecoration.underline))),
        ],
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Implementation
// ══════════════════════════════════════════════════════════════════════════════
class _ImplementationTab extends ConsumerWidget {
  const _ImplementationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedCodeProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFF3B82F6),
          text: '3 code snippets: full HiveKeyRotationService with backup/restore, '
              'biometric-change detection hook from Day 184, '
              'and the manual rotation UI hook.'),
      const SizedBox(height: ZapSpacing.lg),

      ..._kSnippets.asMap().entries.map((e) {
        final i       = e.key;
        final snippet = e.value;
        final isExp   = expanded == i;
        const colors  = [Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF8B5CF6)];
        final color   = colors[i];

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
    Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: const Column(children: [
        Text('🔑', style: TextStyle(fontSize: 44)),
        SizedBox(height: ZapSpacing.md),
        Text('Secure Storage Block',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 14,
                fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.xs),
        Text('DAYS 187 – 188  ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: [
          _Chip('Storage audit ✅',         Color(0xFF10B981)),
          _Chip('4 stores mapped ✅',       Color(0xFF3B82F6)),
          _Chip('10-item data map ✅',      Color(0xFF8B5CF6)),
          _Chip('8 audit checks ✅',        Color(0xFF10B981)),
          _Chip('Key rotation ✅',          Color(0xFF3B82F6)),
          _Chip('3 rotation triggers ✅',   Color(0xFFF59E0B)),
          _Chip('Backup/restore ✅',        Color(0xFF8B5CF6)),
          _Chip('Rotation history ✅',      Color(0xFF10B981)),
          _Chip('3 code snippets ✅',       Color(0xFFF59E0B)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Section C progress
    const _SectionLabel('SECTION C: SECURITY HARDENING  ·  PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    ...[
      (const Color(0xFF10B981), 'Days 181-182', 'Cert Pinning + Network Security Config', true),
      (const Color(0xFF10B981), 'Days 183-184', 'Biometric Lock + LP18 Hardening', true),
      (const Color(0xFF10B981), 'Days 185-186', 'Jailbreak + Root Detection', true),
      (const Color(0xFF10B981), 'Days 187-188', 'Secure Storage + Hive Key Rotation', true),
      (const Color(0xFF3B82F6), 'Days 189-190', 'Security Dashboard + Section C Sign-Off  ←  NEXT', false),
    ].asMap().entries.map((e) {
      final i = e.key;
      final (color, days, title, done) = e.value;
      return Container(
        margin: EdgeInsets.only(bottom: i < 4 ? 2 : 0),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: done
                ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF2A2A2A))),
        child: Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ])),
          if (done)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)
          else
            const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFF3A3A3A), size: 16),
        ]));
    }),
    const SizedBox(height: ZapSpacing.lg),

    // 8/10 progress
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('Section C progress',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        Spacer(),
        Text('8 / 10 days  ·  4 / 5 blocks',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: ZapSpacing.sm),
      ClipRRect(borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
              value: 8 / 10,
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 8)),
    ]),
    const SizedBox(height: ZapSpacing.xl),

    // Days 189-190 preview
    const _SectionLabel('NEXT  ·  DAYS 189-190: SECURITY DASHBOARD + SECTION C SIGN-OFF'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
      child: Column(children: [
        _nextRow('Day 189', '🟢 FRONTEND-ONLY',
            'Security dashboard — single screen showing the status of ALL '
            'Section C security features: cert pinning, biometric, root detection, '
            'storage audit, key rotation. Health score ring.'),
        const Divider(height: 16, color: Color(0xFF1A1A1A)),
        _nextRow('Day 190', '🟢 FRONTEND-ONLY',
            'Section C complete sign-off — all 10 days celebrated. '
            'Security score card. Section D (Store Prep, Days 191-200) preview.'),
      ])),
    const SizedBox(height: ZapSpacing.md),
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF10B981),
        text: 'Days 189-190 remain 🟢 FRONTEND-ONLY. '
            'The security dashboard aggregates results from all Section C screens. '
            'After Day 190 completes Section C, '
            'only Section D (App Store Prep, Days 191-200) remains!'),
  ]);

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
Widget _primaryBtn({required String label, required Color color, VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: onTap != null
                ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                : null,
            color: onTap == null ? const Color(0xFF1A1A1A) : null,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: onTap != null
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                    offset: const Offset(0, 4))]
                : null,
            border: onTap == null
                ? Border.all(color: const Color(0xFF2A2A2A)) : null),
        child: Center(child: Text(label, style: TextStyle(
            color: onTap != null ? Colors.white : const Color(0xFF4B5563),
            fontSize: 13, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center))));

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
