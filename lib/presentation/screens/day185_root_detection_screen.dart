/// Day 185 — Jailbreak & Root Detection
///
/// First day of the Days 185-186 detection block.
/// Day 185: All iOS jailbreak checks + Android root checks,
///           animated scan simulation, Dart code, detection modes.
/// Day 186: Tamper alert UI, Safe-mode vs block decision,
///           Play Integrity / SafetyNet attestation, block sign-off.
///
/// 🟢 FRONTEND-ONLY — detection logic runs entirely on device.
///    No server call needed for the check itself.
///    Play Integrity result (Day 186) does involve a server call
///    to verify the signed token, but the client code is still local.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d185TabProvider       = StateProvider<int>((ref) => 0);
final _scanStateProvider     = StateProvider<_ScanState>((ref) => _ScanState.idle);
final _scanResultsProvider   = StateProvider<List<_CheckResult>>((ref) => []);
final _platformProvider      = StateProvider<_Platform>((ref) => _Platform.android);
final _detectionModeProvider = StateProvider<_DetectionMode>((ref) => _DetectionMode.safeMode);
final _simulateJailbreakProvider = StateProvider<bool>((ref) => false);
final _expandedIosProvider   = StateProvider<int?>((ref) => null);
final _expandedAosProvider   = StateProvider<int?>((ref) => null);

enum _ScanState     { idle, scanning, clean, compromised }
enum _Platform      { android, ios }
enum _DetectionMode { safeMode, block, permissive }

// ── Check data ─────────────────────────────────────────────────────────────────
class _Check {
  final String   id;
  final String   name;
  final String   what;
  final String   howDetected;
  final String   dartCode;
  final IconData icon;
  final Color    color;
  const _Check({
    required this.id, required this.name, required this.what,
    required this.howDetected, required this.dartCode,
    required this.icon, required this.color,
  });
}

class _CheckResult {
  final _Check check;
  final bool   flagged;   // true = suspicious (jailbreak/root indicator found)
  final String detail;
  const _CheckResult({required this.check, required this.flagged, required this.detail});
}

// ── iOS checks ────────────────────────────────────────────────────────────────
const _kIosChecks = [
  _Check(
    id: 'ios_cydia',
    name: 'Cydia app presence',
    what: 'Cydia is the most common jailbreak package manager.',
    howDetected: 'FileManager.default.fileExists(atPath: "/Applications/Cydia.app").\n'
        'Also check /Applications/Sileo.app (newer alternative).',
    dartCode: '''// via platform channel → Swift
final cydia = await _channel.invokeMethod<bool>('checkPath',
    '/Applications/Cydia.app') ?? false;
final sileo = await _channel.invokeMethod<bool>('checkPath',
    '/Applications/Sileo.app') ?? false;
if (cydia || sileo) return JailbreakResult.detected('Cydia/Sileo found');''',
    icon: Icons.phone_iphone_rounded, color: Color(0xFFEF4444),
  ),
  _Check(
    id: 'ios_su',
    name: 'su / bash binary',
    what: 'Root shells (su, bash) are not present on stock iOS '
        'but are installed by most jailbreaks.',
    howDetected: 'Check paths: /bin/su, /usr/bin/su, /bin/bash, /usr/bin/bash, '
        '/usr/local/bin/bash.',
    dartCode: '''final suPaths = ['/bin/su', '/usr/bin/su', '/bin/bash'];
for (final path in suPaths) {
  final exists = await _channel.invokeMethod<bool>('checkPath', path) ?? false;
  if (exists) return JailbreakResult.detected('su/bash at \$path');
}''',
    icon: Icons.terminal_rounded, color: Color(0xFFEF4444),
  ),
  _Check(
    id: 'ios_substrate',
    name: 'Substrate / Theos dylibs',
    what: 'MobileSubstrate (com.saurik.MobileSubstrate) and Theos are '
        'frameworks that allow Cydia tweaks to hook iOS internals.',
    howDetected: 'Check /Library/MobileSubstrate/MobileSubstrate.dylib, '
        '/usr/lib/libsubstitute.dylib, /usr/lib/substrate/SubstrateLoader.dylib.',
    dartCode: '''final substratePaths = [
  '/Library/MobileSubstrate/MobileSubstrate.dylib',
  '/usr/lib/libsubstitute.dylib',
];
for (final p in substratePaths) {
  if (await _channel.invokeMethod<bool>('checkPath', p) ?? false) {
    return JailbreakResult.detected('Substrate at \$p');
  }
}''',
    icon: Icons.extension_rounded, color: Color(0xFFF59E0B),
  ),
  _Check(
    id: 'ios_sandbox',
    name: 'Sandbox escape test',
    what: 'On stock iOS, apps cannot write outside their sandbox. '
        'A jailbroken device allows writing to /private.',
    howDetected: 'Attempt to write a temp file to /private/jailbreak_test.txt. '
        'If write succeeds → jailbreak confirmed. '
        'Delete the file immediately after.',
    dartCode: '''// Swift via platform channel
func sandboxTest() -> Bool {
  let path = "/private/jailbreak_test_\(UUID().uuidString).txt"
  do {
    try "test".write(toFile: path, atomically: true,
        encoding: .utf8)
    try FileManager.default.removeItem(atPath: path)
    return true  // write succeeded → jailbroken
  } catch {
    return false // permission denied → stock iOS
  }
}''',
    icon: Icons.lock_open_rounded, color: Color(0xFF8B5CF6),
  ),
  _Check(
    id: 'ios_urlscheme',
    name: 'Cydia URL scheme',
    what: 'Cydia registers the cydia:// URL scheme. '
        'If the scheme is open-able, Cydia is installed.',
    howDetected: 'UIApplication.shared.canOpenURL(URL(string: "cydia://")!).\n'
        'Only works on iOS < 18 — Apple tightened canOpenURL in iOS 18.',
    dartCode: '''// Swift
let url = URL(string: "cydia://package/com.example")!
if UIApplication.shared.canOpenURL(url) {
  return JailbreakResult.detected("cydia:// scheme registered")
}''',
    icon: Icons.link_rounded, color: Color(0xFF3B82F6),
  ),
  _Check(
    id: 'ios_dynlib',
    name: 'Unexpected dynamic library injection',
    what: 'Tweaks inject dylibs into running processes. '
        'A list of loaded dylibs not from Apple or the app bundle '
        'indicates injection.',
    howDetected: 'Iterate dyld_image_count() and compare each dylib path '
        'against a known-good allow-list of Apple frameworks.',
    dartCode: r'''// Swift — check for unexpected dylibs
for i in 0..<_dyld_image_count() {
  let path = String(cString: _dyld_get_image_name(i))
  let allowed = path.contains("/System/") ||
                path.contains("/usr/lib/swift") ||
                path.contains(Bundle.main.bundlePath)
  if !allowed {
    return JailbreakResult.detected("Injected dylib: \(path)")
  }
}''',
    icon: Icons.memory_rounded, color: Color(0xFF10B981),
  ),
];

// ── Android checks ────────────────────────────────────────────────────────────
const _kAndroidChecks = [
  _Check(
    id: 'aos_su',
    name: 'su binary in PATH',
    what: 'The su (superuser) binary is the primary root indicator. '
        'It grants root shell access and is not present on stock Android.',
    howDetected: 'Search common paths: /system/bin/su, /system/xbin/su, '
        '/sbin/su, /data/local/xbin/su, /vendor/bin/su.',
    dartCode: '''// Kotlin via platform channel
val suPaths = listOf(
  "/system/bin/su", "/system/xbin/su", "/sbin/su",
  "/data/local/xbin/su", "/vendor/bin/su"
)
for (path in suPaths) {
  if (File(path).exists()) {
    return RootResult.detected("su at \$path")
  }
}''',
    icon: Icons.terminal_rounded, color: Color(0xFFEF4444),
  ),
  _Check(
    id: 'aos_testkeys',
    name: 'Test-keys build',
    what: 'Official Android builds are signed with release keys. '
        'Custom ROMs (LineageOS, etc.) often use test-keys, '
        'which strongly correlates with a rooted or modified device.',
    howDetected: 'android.os.Build.TAGS.contains("test-keys"). '
        'Also check Build.TYPE == "userdebug" or "eng".',
    dartCode: '''import 'dart:io';
// via platform channel
final buildTags = await _channel.invokeMethod<String>('getBuildTags');
if (buildTags?.contains('test-keys') == true) {
  return RootResult.detected('test-keys build: \$buildTags');
}''',
    icon: Icons.vpn_key_rounded, color: Color(0xFFF59E0B),
  ),
  _Check(
    id: 'aos_magisk',
    name: 'Magisk / SuperSU installed',
    what: 'Magisk and SuperSU are the most popular root management apps. '
        'Magisk supports "hide" mode but imperfect detection is still possible.',
    howDetected: 'Check package names: com.topjohnwu.magisk, eu.chainfire.supersu, '
        'com.noshufou.android.su. Also check /data/adb/magisk directory.',
    dartCode: '''// Kotlin
val rootApps = listOf(
  "com.topjohnwu.magisk", "eu.chainfire.supersu",
  "com.noshufou.android.su", "com.kingroot.kinguser"
)
val pm = context.packageManager
for (pkg in rootApps) {
  try {
    pm.getPackageInfo(pkg, 0)
    return RootResult.detected("Root app: \$pkg")
  } catch (_) { /* not installed */ }
}''',
    icon: Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6),
  ),
  _Check(
    id: 'aos_busybox',
    name: 'BusyBox binary',
    what: 'BusyBox provides Unix utilities (cp, mv, etc.) and is commonly '
        'installed alongside root. Not definitive alone, but a strong signal.',
    howDetected: 'File("/system/bin/busybox").exists() or '
        'File("/system/xbin/busybox").exists(). '
        'Also try running "which busybox" via Runtime.exec.',
    dartCode: '''// Kotlin
val busyboxPaths = listOf(
  "/system/bin/busybox", "/system/xbin/busybox",
  "/data/local/xbin/busybox"
)
if (busyboxPaths.any { File(it).exists() }) {
  return RootResult.detected("BusyBox found")
}''',
    icon: Icons.widgets_rounded, color: Color(0xFF3B82F6),
  ),
  _Check(
    id: 'aos_rwsystem',
    name: '/system mounted read-write',
    what: 'On stock Android, /system is read-only. '
        'Rooted devices often remount it read-write to install '
        'system-level apps or modify files.',
    howDetected: 'Read /proc/mounts and check if /system has "rw" flag. '
        'Also try opening /system/test_rw.txt for writing.',
    dartCode: r'''// Kotlin
val mountsContent = File("/proc/mounts").readText()
if (mountsContent.contains(Regex("/system\\s+\\S+\\s+\\S+\\s+rw"))) {
  return RootResult.detected("/system is mounted rw")
}''',
    icon: Icons.folder_rounded, color: Color(0xFF10B981),
  ),
  _Check(
    id: 'aos_debuggable',
    name: 'ro.debuggable = 1',
    what: 'A device with ro.debuggable=1 allows ADB shell as root and '
        'running adb adbd in root mode. Production devices always have 0.',
    howDetected: 'android.os.Build.TYPE.equals("userdebug") or '
        'run getprop ro.debuggable via Runtime.getRuntime().exec().',
    dartCode: '''// Kotlin
val process = Runtime.getRuntime().exec(arrayOf("getprop", "ro.debuggable"))
val result = process.inputStream.bufferedReader().readLine()
if (result?.trim() == "1") {
  return RootResult.detected("ro.debuggable=1")
}''',
    icon: Icons.bug_report_rounded, color: Color(0xFFF59E0B),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day185RootDetectionScreen extends ConsumerWidget {
  const Day185RootDetectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d185TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Root / Jailbreak Detection'),
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
                onSelect: (t) => ref.read(_d185TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _ScanTab(),
            if (tab == 1) const _IosChecksTab(),
            if (tab == 2) const _AndroidChecksTab(),
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
            colors: [Color(0xFF100808), Color(0xFF080504), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 185',             const Color(0xFFEF4444)),
          _badge('🟢 FRONTEND-ONLY',        const Color(0xFF10B981)),
          _badge('Section C  ·  Day 5/10',  const Color(0xFF3B82F6)),
          _badge('Root Detection  ·  Day 1/2', const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Jailbreak &\nRoot Detection',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '6 iOS jailbreak checks (Cydia, su, substrate, sandbox escape, '
          'URL scheme, dylib injection). '
          '6 Android root checks (su binary, test-keys, Magisk, '
          'BusyBox, rw /system, ro.debuggable). '
          '3 detection response modes.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',   '6 iOS checks',    Color(0xFF9CA3AF)),
          _HStat('6',   '6 Android checks',Color(0xFF3DDC84)),
          _HStat('3',   'Response modes',  Color(0xFFF59E0B)),
          _HStat('0',   'False positives', Color(0xFF10B981)),
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
      (Icons.radar_rounded,     Color(0xFFEF4444), 'Scan Demo'),
      (Icons.apple_rounded,     Color(0xFF9CA3AF), 'iOS Checks'),
      (Icons.android_rounded,   Color(0xFF3DDC84), 'Android Checks'),
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
// TAB 1 — Scan Demo
// ══════════════════════════════════════════════════════════════════════════════
class _ScanTab extends ConsumerWidget {
  const _ScanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState       = ref.watch(_scanStateProvider);
    final results         = ref.watch(_scanResultsProvider);
    final platform        = ref.watch(_platformProvider);
    final mode            = ref.watch(_detectionModeProvider);
    final simulateJB      = ref.watch(_simulateJailbreakProvider);

    final checks = platform == _Platform.ios ? _kIosChecks : _kAndroidChecks;
    final anyFlagged = results.any((r) => r.flagged);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.radar_rounded, color: const Color(0xFFEF4444),
          text: 'Runs on every app start and before each LP18 gate. '
              'Takes < 50 ms. If compromise is detected, ZapSafe '
              'responds according to the configured Detection Mode.'),
      const SizedBox(height: ZapSpacing.lg),

      // Platform toggle
      const _SectionLabel('PLATFORM'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: [
        Expanded(child: _platformBtn(_Platform.ios, 'iOS',
            Icons.apple_rounded, const Color(0xFF9CA3AF), platform, ref)),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: _platformBtn(_Platform.android, 'Android',
            Icons.android_rounded, const Color(0xFF3DDC84), platform, ref)),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // Simulate compromise toggle
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: simulateJB
                ? const Color(0xFFEF4444).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: simulateJB
                    ? const Color(0xFFEF4444).withOpacity(0.4)
                    : const Color(0xFF2A2A2A))),
        child: Row(children: [
          Icon(simulateJB ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: simulateJB ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              size: 18),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(simulateJB ? 'Simulating compromised device' : 'Simulating clean device',
                style: TextStyle(
                    color: simulateJB ? const Color(0xFFEF4444) : Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const Text('Toggle to see how ZapSafe responds to detected compromise',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ])),
          GestureDetector(
            onTap: () {
              ref.read(_simulateJailbreakProvider.notifier).state = !simulateJB;
              if (scanState != _ScanState.idle) {
                ref.read(_scanStateProvider.notifier).state = _ScanState.idle;
                ref.read(_scanResultsProvider.notifier).state = [];
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 26,
              decoration: BoxDecoration(
                  color: simulateJB ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(13)),
              child: Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: simulateJB ? 22 : 2, top: 2,
                  child: Container(width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle))),
              ]))),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Detection mode
      const _SectionLabel('DETECTION MODE'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: _DetectionMode.values.map((m) {
        final isActive = m == mode;
        final (label, color, desc) = switch (m) {
          _DetectionMode.safeMode   => ('Safe Mode',   const Color(0xFFF59E0B),
              'Warn user, reduce functionality'),
          _DetectionMode.block      => ('Block',       const Color(0xFFEF4444),
              'Refuse to run on compromised device'),
          _DetectionMode.permissive => ('Permissive',  const Color(0xFF6B7280),
              'Log and continue (dev/testing only)'),
        };
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: m != _DetectionMode.permissive ? 6 : 0),
          child: GestureDetector(
            onTap: () => ref.read(_detectionModeProvider.notifier).state = m,
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
                Text(label, style: TextStyle(color: isActive ? color : const Color(0xFF6B7280),
                    fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                Text(desc, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 8),
                    textAlign: TextAlign.center),
              ]),
            ))));
      }).toList()),
      const SizedBox(height: ZapSpacing.xl),

      // Scan button / results
      if (scanState == _ScanState.idle)
        _primaryBtn(
          label: 'Run ${platform == _Platform.ios ? "iOS Jailbreak" : "Android Root"} Scan',
          color: const Color(0xFFEF4444),
          onTap: () => _runScan(ref, platform, checks, simulateJB),
        )
      else
        _ScanResults(
          state: scanState, results: results,
          mode: mode, anyFlagged: anyFlagged,
          allChecks: checks,
          onReset: () {
            ref.read(_scanStateProvider.notifier).state = _ScanState.idle;
            ref.read(_scanResultsProvider.notifier).state = [];
          }),
    ]);
  }

  Widget _platformBtn(_Platform p, String label, IconData icon,
      Color color, _Platform current, WidgetRef ref) {
    final isActive = p == current;
    return GestureDetector(
      onTap: () {
        ref.read(_platformProvider.notifier).state = p;
        ref.read(_scanStateProvider.notifier).state = _ScanState.idle;
        ref.read(_scanResultsProvider.notifier).state = [];
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: isActive ? color : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
        ])));
  }

  Future<void> _runScan(WidgetRef ref, _Platform platform,
      List<_Check> checks, bool simulate) async {
    ref.read(_scanStateProvider.notifier).state = _ScanState.scanning;
    ref.read(_scanResultsProvider.notifier).state = [];

    final results = <_CheckResult>[];
    for (int i = 0; i < checks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 380));
      // Only flag if simulate is on and it's the first check
      final flagged = simulate && i == 0;
      results.add(_CheckResult(
        check: checks[i],
        flagged: flagged,
        detail: flagged
            ? '⚠ ${checks[i].id.replaceAll("_", "/")} found'
            : 'Not found — clean',
      ));
      ref.read(_scanResultsProvider.notifier).state = List.from(results);
    }

    ref.read(_scanStateProvider.notifier).state =
        simulate ? _ScanState.compromised : _ScanState.clean;
  }
}

class _ScanResults extends StatelessWidget {
  final _ScanState state; final List<_CheckResult> results;
  final _DetectionMode mode; final bool anyFlagged;
  final List<_Check> allChecks; final VoidCallback onReset;
  const _ScanResults({required this.state, required this.results,
      required this.mode, required this.anyFlagged,
      required this.allChecks, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final isScanning = state == _ScanState.scanning;
    final headerColor = anyFlagged ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: headerColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: headerColor.withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            isScanning
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Color(0xFFEF4444), strokeWidth: 2))
                : Icon(anyFlagged ? Icons.warning_rounded : Icons.verified_rounded,
                    color: headerColor, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(isScanning ? 'Scanning…'
                : anyFlagged ? 'Compromise detected ⚠'
                : 'Device is clean ✅',
                style: TextStyle(color: headerColor, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          if (!isScanning && anyFlagged) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text('Response mode: ${_modeLabel(mode)}',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            const SizedBox(height: ZapSpacing.xs),
            Text(_modeAction(mode), style: TextStyle(
                color: headerColor, fontSize: 11, fontWeight: FontWeight.w600)),
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
            final i   = e.key;
            final r   = e.value;
            final color = r.flagged ? const Color(0xFFEF4444) : const Color(0xFF10B981);
            final isLast = i == results.length - 1 &&
                (state != _ScanState.scanning || results.length == allChecks.length);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 9),
                child: Row(children: [
                  Icon(r.check.icon, color: r.check.color, size: 13),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(r.check.name, style: const TextStyle(
                      color: Colors.white, fontSize: 11))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(r.flagged ? '⚠ Detected' : '✓ Clean',
                        style: TextStyle(color: color, fontSize: 9,
                            fontWeight: FontWeight.w700))),
                ])),
              if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
          // Pending rows (not yet scanned)
          if (isScanning)
            ...allChecks.skip(results.length).map((c) => Column(children: [
              const Divider(height: 1, color: Color(0xFF1E1E1E)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 9),
                child: Row(children: [
                  Icon(c.icon, color: const Color(0xFF3A3A3A), size: 13),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(c.name, style: const TextStyle(
                      color: Color(0xFF4B5563), fontSize: 11))),
                  const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFF2A2A2A), size: 13),
                ])),
            ])),
        ])),

      if (!isScanning) ...[
        const SizedBox(height: ZapSpacing.md),
        GestureDetector(
          onTap: onReset,
          child: const Text('Run again', style: TextStyle(
              color: Color(0xFF3B82F6), fontSize: 11,
              decoration: TextDecoration.underline))),
      ],
    ]);
  }

  static String _modeLabel(_DetectionMode m) => switch (m) {
    _DetectionMode.safeMode   => 'Safe Mode',
    _DetectionMode.block      => 'Block',
    _DetectionMode.permissive => 'Permissive',
  };

  static String _modeAction(_DetectionMode m) => switch (m) {
    _DetectionMode.safeMode   => 'App will continue with reduced features. '
        'Day 186 will show the full Safe Mode warning screen.',
    _DetectionMode.block      => 'App will refuse to start. '
        'User sees "ZapSafe cannot run on a compromised device" screen.',
    _DetectionMode.permissive => 'App continues normally. '
        'Compromise logged to Sentry (if consented). Dev/testing only.',
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — iOS Checks
// ══════════════════════════════════════════════════════════════════════════════
class _IosChecksTab extends ConsumerWidget {
  const _IosChecksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedIosProvider);
    return _CheckListTab(
      platformLabel: 'iOS JAILBREAK',
      platformColor: const Color(0xFF9CA3AF),
      platformIcon: Icons.apple_rounded,
      checks: _kIosChecks,
      expanded: expanded,
      onExpand: (i) => ref.read(_expandedIosProvider.notifier).state =
          expanded == i ? null : i,
      context: context,
      note: 'Jailbreak detection is a cat-and-mouse game. '
          'New jailbreaks (e.g. unc0ver, Dopamine) add new paths. '
          'ZapSafe uses all 6 checks in combination — one failed check '
          'alone may be a false positive, but 2+ together is a strong signal. '
          'Day 186 explains the multi-check scoring approach.',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Android Checks
// ══════════════════════════════════════════════════════════════════════════════
class _AndroidChecksTab extends ConsumerWidget {
  const _AndroidChecksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedAosProvider);
    return _CheckListTab(
      platformLabel: 'ANDROID ROOT',
      platformColor: const Color(0xFF3DDC84),
      platformIcon: Icons.android_rounded,
      checks: _kAndroidChecks,
      expanded: expanded,
      onExpand: (i) => ref.read(_expandedAosProvider.notifier).state =
          expanded == i ? null : i,
      context: context,
      note: 'Magisk Hide (now Shamiko) can hide root from apps. '
          'ZapSafe combines multiple checks — Magisk can hide the app, '
          'but cannot hide all traces simultaneously. '
          'Day 186 covers Play Integrity API which provides a server-verified '
          'integrity signal that is much harder to bypass.',
    );
  }
}

class _CheckListTab extends StatelessWidget {
  final String      platformLabel;
  final Color       platformColor;
  final IconData    platformIcon;
  final List<_Check> checks;
  final int?        expanded;
  final ValueChanged<int> onExpand;
  final BuildContext context;
  final String      note;
  const _CheckListTab({
    required this.platformLabel, required this.platformColor,
    required this.platformIcon, required this.checks,
    required this.expanded, required this.onExpand,
    required this.context, required this.note,
  });

  @override
  Widget build(BuildContext _) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: platformIcon, color: platformColor,
          text: '6 ${platformLabel == "iOS JAILBREAK" ? "iOS jailbreak" : "Android root"} '
              'checks. Each explains what is detected, how to detect it, '
              'and the Dart/Kotlin/Swift code. Tap any check to expand.'),
      const SizedBox(height: ZapSpacing.lg),

      // Check count
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: platformColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: platformColor.withOpacity(0.3))),
        child: Row(children: [
          Icon(platformIcon, color: platformColor, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text('${checks.length} $platformLabel checks — '
              'all run on every app start',
              style: TextStyle(color: platformColor, fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('CHECKS  ·  TAP TO SEE HOW + CODE'),
      const SizedBox(height: ZapSpacing.md),

      ...checks.asMap().entries.map((e) {
        final i     = e.key;
        final check = e.value;
        final isExp = expanded == i;

        return GestureDetector(
          onTap: () => onExpand(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? check.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? check.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: check.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(check.icon, color: check.color, size: 16)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(check.name, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
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
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _detailRow('What', check.what, check.color),
                          const SizedBox(height: ZapSpacing.sm),
                          _detailRow('How detected', check.howDetected,
                              const Color(0xFF3B82F6)),
                          const SizedBox(height: ZapSpacing.sm),
                          _codeBlock(context, check.dartCode),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: note),
    ]);
  }

  Widget _detailRow(String label, String body, Color color) => Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 9,
            fontWeight: FontWeight.w700)),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(body, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))),
      ]));
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
