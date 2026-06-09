import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Outcome of a single permission request.
enum PermissionOutcome {
  granted,
  denied,
  /// User ticked "Never ask again" (Android) / has previously denied on iOS.
  /// Must direct user to system Settings to resolve.
  deniedForever,
}

/// Snapshot of all five safety-critical permissions.
class PermissionsResult {
  final PermissionOutcome microphone;
  final PermissionOutcome locationAlways;
  final PermissionOutcome camera;
  final PermissionOutcome notifications;
  final PermissionOutcome activityRecognition;

  const PermissionsResult({
    required this.microphone,
    required this.locationAlways,
    required this.camera,
    required this.notifications,
    required this.activityRecognition,
  });

  bool get allGranted =>
      microphone == PermissionOutcome.granted &&
      locationAlways == PermissionOutcome.granted &&
      camera == PermissionOutcome.granted &&
      notifications == PermissionOutcome.granted &&
      activityRecognition == PermissionOutcome.granted;

  bool get anyDeniedForever =>
      microphone == PermissionOutcome.deniedForever ||
      locationAlways == PermissionOutcome.deniedForever ||
      camera == PermissionOutcome.deniedForever ||
      notifications == PermissionOutcome.deniedForever ||
      activityRecognition == PermissionOutcome.deniedForever;

  bool get anyDenied => !allGranted;
}

/// Basic device metadata collected via device_info_plus.
class DeviceBasicInfo {
  final String model;
  final String manufacturer;
  final String osVersion;

  const DeviceBasicInfo({
    required this.model,
    required this.manufacturer,
    required this.osVersion,
  });
}

/// Handles runtime permission requests and device info collection.
///
/// Call [requestAll] to present system dialogs in the correct order:
///   microphone → locationAlways → camera → notifications → activityRecognition
///
/// Call [checkAll] to read current statuses without prompting.
/// When [PermissionOutcome.deniedForever] is returned, call [openSettings].
class PermissionService {
  static PermissionOutcome _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermissionOutcome.granted;
    if (s.isPermanentlyDenied) return PermissionOutcome.deniedForever;
    return PermissionOutcome.denied;
  }

  /// Requests all five permissions sequentially and returns outcomes.
  Future<PermissionsResult> requestAll() async {
    final mic = await Permission.microphone.request();
    final loc = await Permission.locationAlways.request();
    final cam = await Permission.camera.request();
    final notif = await Permission.notification.request();
    final activity = await Permission.activityRecognition.request();

    return PermissionsResult(
      microphone: _map(mic),
      locationAlways: _map(loc),
      camera: _map(cam),
      notifications: _map(notif),
      activityRecognition: _map(activity),
    );
  }

  /// Requests a single permission identified by name. Used by the onboarding
  /// flow which presents permissions one at a time. Returns the resulting
  /// outcome for just that permission.
  ///
  /// Accepts an opaque `id` that maps to one of the five permissions the app
  /// requests. Unknown ids return [PermissionOutcome.denied] without prompting.
  Future<PermissionOutcome> requestOne(Object id) async {
    final name = id.toString().split('.').last;
    final PermissionStatus result;
    switch (name) {
      case 'microphone':
        result = await Permission.microphone.request();
        break;
      case 'locationAlways':
        result = await Permission.locationAlways.request();
        break;
      case 'camera':
        result = await Permission.camera.request();
        break;
      case 'notifications':
        result = await Permission.notification.request();
        break;
      case 'activity':
        result = await Permission.activityRecognition.request();
        break;
      default:
        return PermissionOutcome.denied;
    }
    return _map(result);
  }

  /// Reads current statuses without showing any system dialogs.
  Future<PermissionsResult> checkAll() async {
    final mic = await Permission.microphone.status;
    final loc = await Permission.locationAlways.status;
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;
    final activity = await Permission.activityRecognition.status;

    return PermissionsResult(
      microphone: _map(mic),
      locationAlways: _map(loc),
      camera: _map(cam),
      notifications: _map(notif),
      activityRecognition: _map(activity),
    );
  }

  /// Opens the app's page in system Settings.
  Future<void> openSettings() => openAppSettings();

  /// Returns basic device metadata (model, OS version, manufacturer).
  Future<DeviceBasicInfo> deviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return DeviceBasicInfo(
        model: info.model,
        manufacturer: info.manufacturer,
        osVersion: 'Android ${info.version.release} (API ${info.version.sdkInt})',
      );
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return DeviceBasicInfo(
        model: info.model,
        manufacturer: 'Apple',
        osVersion: 'iOS ${info.systemVersion}',
      );
    }
    return const DeviceBasicInfo(
      model: 'Unknown',
      manufacturer: 'Unknown',
      osVersion: 'Unknown',
    );
  }
}
