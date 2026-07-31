import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/services/background_service.dart';
import 'audio_features.dart';
import 'audio_frame.dart';
import 'imu_sample.dart';
import 'pcm_window.dart';

/// Day 23 — single source of truth for every Flutter ↔ native channel.
///
/// The codebase had two ad-hoc channels (`com.zapsafe/background_service`
/// from Day 21, `com.zapsafe/ios_background` from Day 22). Day 23 adds two
/// more — sensor stream + audio capture — and consolidates the channel
/// constants so the native side and Flutter side can never drift.
///
/// Naming convention: `com.zapsafe/<domain>` for MethodChannels, plus
/// `com.zapsafe/<domain>.events` for the matching EventChannel when streams
/// are involved.

// ─── Channel name registry ───────────────────────────────────────────────────

/// Channel identifiers — mirrored byte-for-byte in
/// `MainActivity.kt` (Android) and Swift handlers (iOS).
abstract final class PlatformChannelNames {
  static const backgroundService = BackgroundService.channelName;
  static const iosBackground     = 'com.zapsafe/ios_background';
  static const sensors           = 'com.zapsafe/sensors';
  static const sensorsEvents     = 'com.zapsafe/sensors.events';
  static const audio             = 'com.zapsafe/audio';
  static const audioEvents       = 'com.zapsafe/audio.events';
  static const audioFeatures     = 'com.zapsafe/audio.features';
  /// Day 258 — rolling 3 s raw PCM windows for the m1_scream_v2 mel pipeline.
  static const audioPcm          = 'com.zapsafe/audio.pcm';
  static const watchdog          = 'com.zapsafe/watchdog';
  // Day 38 — cell-tower / WiFi fallback (TelephonyManager on Android,
  // CTTelephonyNetworkInfo on iOS). Native side is a stub today; Dart
  // façade degrades to "no estimate" if the channel is missing.
  static const cell              = 'com.zapsafe/cell';
}

// ─── BackgroundServiceChannel ────────────────────────────────────────────────

/// Re-export of [BackgroundService] under the "channel" naming so it sits
/// alongside the new channels added in Day 23. No behaviour change —
/// existing callers can keep using `BackgroundService` directly.
typedef BackgroundServiceChannel = BackgroundService;

// ─── SensorChannel · IMU EventChannel ────────────────────────────────────────

/// State of the sensor stream from Flutter's point of view.
enum SensorStreamState { idle, streaming, error }

/// Thin façade over the `com.zapsafe/sensors.events` EventChannel. Subscribe
/// to [stream] to receive [ImuSample]s; call [start] / [stop] on the matching
/// MethodChannel to gate the native side.
///
/// Day 23 = scaffold. Real hardware reads land in Day 28 (`SensorChannelHandler.kt`
/// will wire `SensorManager.SENSOR_DELAY_GAME` for both accel + gyro). Today's
/// Kotlin stub emits a synthetic 10-Hz waveform so the Flutter side is fully
/// exercisable before the real sensor code lands.
class SensorChannel {
  final MethodChannel _methods;
  final EventChannel _events;

  SensorChannel({MethodChannel? methods, EventChannel? events})
      : _methods = methods ?? const MethodChannel(PlatformChannelNames.sensors),
        _events = events ?? const EventChannel(PlatformChannelNames.sensorsEvents);

  /// True when the host platform has a native handler today.
  /// Android: implemented. iOS: stub coming later (deferred to Days 28+).
  bool get supported => Platform.isAndroid;

  /// Starts the native IMU pipeline. Returns true on success.
  Future<bool> start() async {
    if (!supported) return false;
    try {
      return (await _methods.invokeMethod<bool>('start')) ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[sensors] start failed: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Stops the native IMU pipeline. Idempotent.
  Future<bool> stop() async {
    if (!supported) return true;
    try {
      await _methods.invokeMethod<bool>('stop');
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
    return true;
  }

  /// Live broadcast stream of [ImuSample]s. Subscribers receive the same
  /// events — safe to listen multiple times. Closing the last subscription
  /// does NOT stop the native pipeline; call [stop] explicitly.
  Stream<ImuSample> get stream {
    if (!supported) return const Stream.empty();
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return ImuSample.fromMap(event);
      }
      // Defensive fallback for malformed frames.
      return const ImuSample(
        timestampMs: 0, ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0,
      );
    });
  }
}

// ─── AudioChannel · MethodChannel for capture control ────────────────────────

/// Current state of the native audio capture pipeline.
enum AudioCaptureState { idle, recording, error }

/// Façade over `com.zapsafe/audio` (control) + `com.zapsafe/audio.events`
/// (frame stream). Day 26 wired the Android `AudioRecord` path; Day 28 added
/// the iOS `AVAudioEngine` counterpart. Both platforms emit `AudioFrame`s on
/// the same channels with the same payload schema, so the Flutter side has
/// no platform branching.
///
/// Features (`com.zapsafe/audio.features`) are still Android-only until the
/// Swift `MfccExtractor` lands (planned Day 29) — `featureStream` will be
/// empty on iOS but won't error.
class AudioChannel {
  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final EventChannel _featuresChannel;
  final EventChannel _pcmChannel;

  AudioChannel({
    MethodChannel? channel,
    EventChannel? events,
    EventChannel? features,
    EventChannel? pcm,
  })  : _channel = channel ?? const MethodChannel(PlatformChannelNames.audio),
        _eventChannel = events ?? const EventChannel(PlatformChannelNames.audioEvents),
        _featuresChannel = features ?? const EventChannel(PlatformChannelNames.audioFeatures),
        _pcmChannel = pcm ?? const EventChannel(PlatformChannelNames.audioPcm);

  /// True when the host platform has a native capture handler. Android via
  /// `AudioRecord` (Day 26) and iOS via `AVAudioEngine` (Day 28).
  bool get supported => Platform.isAndroid || Platform.isIOS;

  /// True when the host platform has a feature-extraction handler. Android
  /// today (Day 27); iOS lands on Day 29. The [featureStream] safely
  /// returns nothing on iOS until then.
  bool get featuresSupported => Platform.isAndroid;

  /// Starts capture. Returns true on success.
  ///
  /// On Android, this throws via the native side if the RECORD_AUDIO
  /// permission is denied — the Dart wrapper converts the exception into a
  /// `false` return so callers can branch on a single value.
  Future<bool> start() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>('start')) ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[audio] start failed: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Stops capture. Idempotent.
  Future<bool> stop() async {
    if (!supported) return true;
    try {
      await _channel.invokeMethod<bool>('stop');
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
    return true;
  }

  /// Returns the native side's notion of whether capture is currently running.
  /// Off-platform: false.
  Future<bool> isRecording() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>('isRecording')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Day 26 — broadcast stream of [AudioFrame]s emitted at the 450 ms
  /// window cadence. Subscribers receive the same events; closing the last
  /// subscription does NOT stop the native capture — call [stop] explicitly.
  Stream<AudioFrame> get frameStream {
    if (!supported) return const Stream.empty();
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) return AudioFrame.fromMap(event);
      return const AudioFrame(
        timestampMs: 0, rmsEnergy: 0, voiced: false,
        sampleCount: 0, windowMs: 0, threshold: 0,
      );
    });
  }

  /// The VAD RMS threshold the native side uses for this build. Off-platform: 0.
  Future<double> readVadThreshold() async {
    if (!supported) return 0;
    try {
      final v = await _channel.invokeMethod<num>('vadThreshold');
      return v?.toDouble() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// The capture sample rate in Hz (16 000 today). Off-platform: 0.
  Future<int> readSampleRateHz() async {
    if (!supported) return 0;
    try {
      return (await _channel.invokeMethod<num>('sampleRateHz'))?.toInt() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// The sliding-window length in ms (450 today). Off-platform: 0.
  Future<int> readWindowMs() async {
    if (!supported) return 0;
    try {
      return (await _channel.invokeMethod<num>('windowMs'))?.toInt() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Day 27 — broadcast stream of feature vectors, emitted once per voiced
  /// 450 ms window. Silent windows do not emit. Empty stream on platforms
  /// that don't yet implement feature extraction (iOS — lands Day 29).
  Stream<AudioFeatures> get featureStream {
    if (!featuresSupported) return const Stream.empty();
    return _featuresChannel.receiveBroadcastStream().map((event) {
      if (event is Map) return AudioFeatures.fromMap(event);
      return const AudioFeatures(
        timestampMs: 0,
        mfcc: [],
        zcr: 0,
        spectralCentroidHz: 0,
      );
    });
  }

  /// Day 258 — broadcast stream of rolling 3 s raw PCM windows for
  /// m1_scream_v2. Emitted every ~1 s (the native hop), overlapping.
  /// Malformed events decode to an unusable [PcmWindow] rather than
  /// throwing — [ScreamAudioPipeline] already drops those.
  Stream<PcmWindow> get pcmStream {
    if (!supported) return const Stream.empty();
    return _pcmChannel.receiveBroadcastStream().map((event) {
      if (event is Map) return PcmWindow.fromMap(event);
      return PcmWindow(timestampMs: 0, sampleRateHz: 0, pcmBytes: Uint8List(0));
    });
  }

  /// Number of MFCC coefficients the native side ships (13 today).
  Future<int> readMfccCount() async {
    if (!supported) return 0;
    try {
      return (await _channel.invokeMethod<num>('mfccCount'))?.toInt() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Number of mel filterbank bins (26 today). Useful for the Day 27 screen.
  Future<int> readMelBins() async {
    if (!supported) return 0;
    try {
      return (await _channel.invokeMethod<num>('melBins'))?.toInt() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// FFT window size in samples (8192 today).
  Future<int> readFftSize() async {
    if (!supported) return 0;
    try {
      return (await _channel.invokeMethod<num>('fftSize'))?.toInt() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }
}

// ─── WatchdogChannel · LP4 ───────────────────────────────────────────────────

/// Live status read out of the watchdog: the last heartbeat, how stale it is,
/// and the configured threshold for comparison.
@immutable
class WatchdogStatus {
  /// Wall-clock millis since epoch of the last service heartbeat, or null
  /// when the engine has never written one (cold install / freshly cleared).
  final int? lastHeartbeatMs;

  /// Seconds since [lastHeartbeatMs], or null when no heartbeat exists.
  final int? secondsSinceLastPing;

  /// LP4 threshold the native side enforces. Falls back to 30s if the
  /// channel returns null (off-platform).
  final int thresholdMs;

  const WatchdogStatus({
    required this.lastHeartbeatMs,
    required this.secondsSinceLastPing,
    required this.thresholdMs,
  });

  /// True when the engine has missed the LP4 threshold. Returns true when
  /// no heartbeat has ever fired — that's the "service never started" case.
  bool get isStale {
    final s = secondsSinceLastPing;
    if (s == null) return true;
    return s * 1000 > thresholdMs;
  }
}

/// Façade over `com.zapsafe/watchdog`. Drives the periodic LP4 work and
/// surfaces the most recent heartbeat for UI inspection.
class WatchdogChannel {
  final MethodChannel _channel;

  WatchdogChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(PlatformChannelNames.watchdog);

  bool get supported => Platform.isAndroid;

  /// Default LP4 threshold (30 s) — used as the fallback on hosts that can't
  /// query the native side.
  static const int defaultThresholdMs = 30000;

  /// Schedules the periodic 15-min watchdog. Idempotent: subsequent calls
  /// keep the existing schedule rather than restarting the timer.
  Future<bool> enqueue() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>('enqueue')) ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[watchdog] enqueue failed: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Cancels the periodic watchdog. Idempotent.
  Future<bool> cancel() async {
    if (!supported) return true;
    try {
      return (await _channel.invokeMethod<bool>('cancel')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Day 25 — true when the WorkManager periodic watchdog is currently
  /// enqueued or running. Off-platform: false.
  Future<bool> isEnqueued() async {
    if (!supported) return false;
    try {
      return (await _channel.invokeMethod<bool>('isEnqueued')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Reads the watchdog's current view of the engine. Off-platform: returns a
  /// stale snapshot (null heartbeat + default threshold) so UIs render
  /// without special-casing.
  Future<WatchdogStatus> readStatus() async {
    if (!supported) {
      return const WatchdogStatus(
        lastHeartbeatMs: null,
        secondsSinceLastPing: null,
        thresholdMs: defaultThresholdMs,
      );
    }
    try {
      final last  = await _channel.invokeMethod<int>('lastHeartbeatMs');
      final since = await _channel.invokeMethod<int>('secondsSinceLastPing');
      final thr   = await _channel.invokeMethod<int>('thresholdMs');
      return WatchdogStatus(
        lastHeartbeatMs: last,
        secondsSinceLastPing: since,
        thresholdMs: thr ?? defaultThresholdMs,
      );
    } on PlatformException {
      return const WatchdogStatus(
        lastHeartbeatMs: null,
        secondsSinceLastPing: null,
        thresholdMs: defaultThresholdMs,
      );
    } on MissingPluginException {
      return const WatchdogStatus(
        lastHeartbeatMs: null,
        secondsSinceLastPing: null,
        thresholdMs: defaultThresholdMs,
      );
    }
  }
}
