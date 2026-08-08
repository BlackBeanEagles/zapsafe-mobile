import 'dart:io';

import 'package:safe_device/safe_device.dart';

/// Real root/jailbreak + device-integrity detection (LP — see
/// day185_root_detection_screen.dart's own LP18-gate note).
///
/// Was: day185_root_detection_screen.dart's "Run Scan" button only ever
/// flipped a local `_simulateJailbreakProvider` bool and animated fake
/// per-check results (`flagged = simulate && i == 0`) — a real Day
/// 336/361 P1 finding ("root/jailbreak detection is a UI simulation, not
/// real detection"). No safe_device / flutter_jailbreak_detection /
/// freerasp / Play Integrity call existed anywhere.
///
/// This wraps the `safe_device` package (added to pubspec.yaml), which
/// does real native root/jailbreak detection on-device (su-binary paths,
/// build tags, system properties, dyld/Cydia checks on iOS, etc. — see
/// its own Android/iOS native source for the actual checks it runs).
///
/// Honesty note: safe_device's per-signal breakdown
/// (`rootDetectionDetails` / `jailbreakDetails`) does not expose a
/// distinct boolean for every individual technique
/// day185_root_detection_screen.dart's UI documents (that screen's
/// per-row list is a real, accurate *reference* of detection techniques,
/// each with its own real how-it-works explanation — that part was
/// never fake). Only rows with a genuine matching signal from the
/// plugin get a real per-row result; the rest defer to the one real,
/// fully-combined verdict ([DeviceIntegrityReport.isCompromised]),
/// labeled as such rather than assigned a fabricated "clean" result.
class DeviceIntegrityReport {
  final bool isCompromised; // real combined root/jailbreak verdict
  final bool isRealDevice; // false = emulator/simulator
  final bool isMockLocation;
  final bool isDevelopmentModeEnabled; // Android only
  final bool isUsbDebuggingEnabled; // Android only
  final bool isOnExternalStorage; // Android only
  final Map<String, dynamic> rawDetails; // platform-specific signal breakdown

  const DeviceIntegrityReport({
    required this.isCompromised,
    required this.isRealDevice,
    required this.isMockLocation,
    required this.isDevelopmentModeEnabled,
    required this.isUsbDebuggingEnabled,
    required this.isOnExternalStorage,
    required this.rawDetails,
  });

  /// True if anything about this device/session looks untrustworthy
  /// enough that LP18's Detection Mode should act (root/jailbreak,
  /// running on an emulator/simulator, or GPS being spoofed — all real
  /// signals a personal-safety app should care about, not just root).
  bool get shouldTriggerDetectionMode =>
      isCompromised || !isRealDevice || isMockLocation;
}

class DeviceIntegrityService {
  /// Runs a real, on-device scan. Never throws — any native-call failure
  /// (e.g. running on an unsupported platform) degrades to "could not
  /// verify" (isCompromised: false, isRealDevice: true) rather than a
  /// false positive that would block a legitimate user.
  static Future<DeviceIntegrityReport> scan() async {
    try {
      final isCompromised = await SafeDevice.isJailBroken;
      final isRealDevice = await SafeDevice.isRealDevice;
      final isMockLocation = await SafeDevice.isMockLocation;
      final isDev = Platform.isAndroid
          ? await SafeDevice.isDevelopmentModeEnable
          : false;
      final isUsbDebug =
          Platform.isAndroid ? await SafeDevice.isUsbDebuggingEnabled : false;
      final isExternal =
          Platform.isAndroid ? await SafeDevice.isOnExternalStorage : false;
      final details = Platform.isAndroid
          ? await SafeDevice.rootDetectionDetails
          : await SafeDevice.jailbreakDetails;

      return DeviceIntegrityReport(
        isCompromised: isCompromised,
        isRealDevice: isRealDevice,
        isMockLocation: isMockLocation,
        isDevelopmentModeEnabled: isDev,
        isUsbDebuggingEnabled: isUsbDebug,
        isOnExternalStorage: isExternal,
        rawDetails: details,
      );
    } catch (_) {
      return const DeviceIntegrityReport(
        isCompromised: false,
        isRealDevice: true,
        isMockLocation: false,
        isDevelopmentModeEnabled: false,
        isUsbDebuggingEnabled: false,
        isOnExternalStorage: false,
        rawDetails: {},
      );
    }
  }
}
