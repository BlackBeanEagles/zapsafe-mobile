import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ZapSafe device capability tier.
///
/// Tier classification drives which safety features are enabled at runtime —
/// high-end devices get full AI + HD evidence; low-end devices run the safe
/// core without heavy compute.
enum DeviceTier {
  /// Android API 31+ (Android 12+) / iOS 16+
  /// Full AI inference, HD video evidence, all sensors active.
  tierA,

  /// Android API 24–30 (Android 7–11) / iOS 13–15
  /// Most features active, 720p video, selective AI (rule-based fallback).
  tierB,

  /// Android API < 24 (Android < 7) / iOS < 13
  /// Core safety only: audio evidence, basic GPS, no on-device AI.
  tierC,
}

extension DeviceTierLabel on DeviceTier {
  String get label => switch (this) {
        DeviceTier.tierA => 'Tier A · High-end',
        DeviceTier.tierB => 'Tier B · Mid-range',
        DeviceTier.tierC => 'Tier C · Essential',
      };

  String get shortLabel => switch (this) {
        DeviceTier.tierA => 'TIER A',
        DeviceTier.tierB => 'TIER B',
        DeviceTier.tierC => 'TIER C',
      };

  String get description => switch (this) {
        DeviceTier.tierA =>
          'Full feature set: on-device AI, HD video evidence, all passive triggers active.',
        DeviceTier.tierB =>
          'Most features active with rule-based AI fallback; 720p video evidence.',
        DeviceTier.tierC =>
          'Core safety mode: GPS tracking, audio evidence, manual SOS only.',
      };
}

/// Full classification result from [DeviceTierService.detect].
class DeviceTierResult {
  final DeviceTier tier;
  final String model;
  final String manufacturer;
  final String osVersion;

  /// Android API level, or iOS major version (e.g. 16 for iOS 16.x).
  final int osLevelOrVersion;

  /// Features fully supported on this device.
  final List<String> enabledFeatures;

  /// Features unavailable on this device due to tier constraints.
  final List<String> disabledFeatures;

  const DeviceTierResult({
    required this.tier,
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.osLevelOrVersion,
    required this.enabledFeatures,
    required this.disabledFeatures,
  });
}

/// Detects the device capability tier using [device_info_plus].
///
/// Classification is based on OS API level / major iOS version:
///
/// | Platform | Tier A      | Tier B        | Tier C   |
/// |----------|-------------|---------------|----------|
/// | Android  | API ≥ 31    | API 24–30     | API < 24 |
/// | iOS      | iOS ≥ 16    | iOS 13–15     | iOS < 13 |
///
/// Call [detect] once on app start and store result in [deviceTierProvider].
/// Detection result is cached via [SharedPreferences] under [_cacheKey] so
/// subsequent app launches can read the tier synchronously without re-running
/// device-info I/O.
class DeviceTierService {
  static const _cacheKey = 'zapsafe.device_tier.v1';
  static const _cacheKeyModel = 'zapsafe.device_tier.v1.model';
  static const _cacheKeyOs = 'zapsafe.device_tier.v1.os';
  static const _cacheKeyApi = 'zapsafe.device_tier.v1.api';

  static const _featuresA = [
    'On-device AI inference (TFLite)',
    'HD video evidence (1080p)',
    'Blink-code trigger (camera)',
    'Impact detection (IMU)',
    'Passive audio monitoring',
    'Background GPS tracking',
    'Real-time location sharing',
    'Push notifications',
  ];

  static const _featuresB = [
    '720p video evidence',
    'Rule-based trigger detection',
    'Background GPS tracking',
    'Real-time location sharing',
    'Push notifications',
    'Audio evidence recording',
  ];

  static const _featuresC = [
    'Manual SOS button',
    'Basic GPS tracking',
    'Audio evidence recording',
    'Push notifications',
  ];

  static const _disabledB = [
    'On-device AI inference',
    'HD video evidence (1080p)',
    'Blink-code trigger',
    'Impact detection (IMU)',
  ];

  static const _disabledC = [
    'On-device AI inference',
    'HD / 720p video evidence',
    'Blink-code trigger',
    'Impact detection (IMU)',
    'Passive audio monitoring',
    'Real-time location sharing',
  ];

  /// Returns the cached tier if present, otherwise runs [detect] and caches
  /// the result. Use this in the app's startup flow.
  Future<DeviceTierResult> loadOrDetect() async {
    final cached = await _readCache();
    if (cached != null) return cached;
    final fresh = await detect();
    await _writeCache(fresh);
    return fresh;
  }

  /// Clears the cached tier. Mainly useful for testing.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheKeyModel);
    await prefs.remove(_cacheKeyOs);
    await prefs.remove(_cacheKeyApi);
  }

  Future<DeviceTierResult?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierName = prefs.getString(_cacheKey);
      if (tierName == null) return null;
      final tier = DeviceTier.values.firstWhere(
        (t) => t.name == tierName,
        orElse: () => DeviceTier.tierB,
      );
      return DeviceTierResult(
        tier: tier,
        model: prefs.getString(_cacheKeyModel) ?? 'Unknown',
        manufacturer: 'Cached',
        osVersion: prefs.getString(_cacheKeyOs) ?? 'Unknown',
        osLevelOrVersion: prefs.getInt(_cacheKeyApi) ?? 0,
        enabledFeatures: _enabled(tier),
        disabledFeatures: _disabled(tier),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(DeviceTierResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, result.tier.name);
      await prefs.setString(_cacheKeyModel, result.model);
      await prefs.setString(_cacheKeyOs, result.osVersion);
      await prefs.setInt(_cacheKeyApi, result.osLevelOrVersion);
    } catch (_) {
      // Cache failures are non-fatal — detection still works.
    }
  }

  /// Detects and returns the device tier. Never throws — returns Tier B as a
  /// safe default if detection fails.
  Future<DeviceTierResult> detect() async {
    try {
      final plugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final sdk = info.version.sdkInt;
        final tier = _tierForAndroid(sdk);
        return DeviceTierResult(
          tier: tier,
          model: info.model,
          manufacturer: info.manufacturer,
          osVersion: 'Android ${info.version.release} (API $sdk)',
          osLevelOrVersion: sdk,
          enabledFeatures: _enabled(tier),
          disabledFeatures: _disabled(tier),
        );
      }

      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final major = int.tryParse(info.systemVersion.split('.').first) ?? 14;
        final tier = _tierForIos(major);
        return DeviceTierResult(
          tier: tier,
          model: info.model,
          manufacturer: 'Apple',
          osVersion: 'iOS ${info.systemVersion}',
          osLevelOrVersion: major,
          enabledFeatures: _enabled(tier),
          disabledFeatures: _disabled(tier),
        );
      }
    } catch (_) {
      // Fall through to safe default.
    }

    // Unknown platform — treat as Tier B (safe fallback).
    return const DeviceTierResult(
      tier: DeviceTier.tierB,
      model: 'Unknown',
      manufacturer: 'Unknown',
      osVersion: 'Unknown',
      osLevelOrVersion: 0,
      enabledFeatures: _featuresB,
      disabledFeatures: _disabledB,
    );
  }

  static DeviceTier _tierForAndroid(int sdk) {
    if (sdk >= 31) return DeviceTier.tierA;
    if (sdk >= 24) return DeviceTier.tierB;
    return DeviceTier.tierC;
  }

  static DeviceTier _tierForIos(int major) {
    if (major >= 16) return DeviceTier.tierA;
    if (major >= 13) return DeviceTier.tierB;
    return DeviceTier.tierC;
  }

  static List<String> _enabled(DeviceTier t) => switch (t) {
        DeviceTier.tierA => _featuresA,
        DeviceTier.tierB => _featuresB,
        DeviceTier.tierC => _featuresC,
      };

  static List<String> _disabled(DeviceTier t) => switch (t) {
        DeviceTier.tierA => const [],
        DeviceTier.tierB => _disabledB,
        DeviceTier.tierC => _disabledC,
      };
}
