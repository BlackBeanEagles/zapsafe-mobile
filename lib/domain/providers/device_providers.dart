import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/device_tier_service.dart';

/// Singleton service instance.
final deviceTierServiceProvider = Provider((_) => DeviceTierService());

/// Detects the device tier once on first access and caches the result.
/// Safe to watch from any widget — always returns a non-null DeviceTierResult
/// (falls back to Tier B on error).
final deviceTierProvider = FutureProvider<DeviceTierResult>((ref) {
  return ref.read(deviceTierServiceProvider).loadOrDetect();
});
