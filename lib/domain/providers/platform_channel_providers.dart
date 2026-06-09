import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../native/audio_features.dart';
import '../../native/audio_frame.dart';
import '../../native/imu_sample.dart';
import '../../native/platform_channels.dart';

/// Day 23 — singletons for the consolidated platform channels.
///
/// [BackgroundServiceChannel] continues to live behind
/// `backgroundServiceProvider` (Day 21) and is not re-exported here, so
/// callers don't need to migrate.

final sensorChannelProvider = Provider<SensorChannel>((_) => SensorChannel());

final audioChannelProvider = Provider<AudioChannel>((_) => AudioChannel());

/// Broadcast IMU stream. Wraps the channel's stream so multiple widgets can
/// subscribe simultaneously without spawning extra native subscriptions.
final imuStreamProvider = StreamProvider<ImuSample>((ref) {
  return ref.watch(sensorChannelProvider).stream;
});

/// Last-known audio-recording state. Polled by the Day 23 screen — refresh
/// to re-query the native side.
final audioRecordingProvider = FutureProvider<bool>((ref) async {
  return ref.watch(audioChannelProvider).isRecording();
});

// ─── Day 26 · live audio frames ──────────────────────────────────────────────

/// Broadcast stream of audio frames emitted at the 450 ms cadence.
final audioFrameStreamProvider = StreamProvider<AudioFrame>((ref) {
  return ref.watch(audioChannelProvider).frameStream;
});

/// Static capture specs (sample rate, window length, VAD threshold) read
/// from the native side once on first access.
final audioCaptureSpecProvider =
    FutureProvider<({int sampleRateHz, int windowMs, double vadThreshold})>(
        (ref) async {
  final ch = ref.watch(audioChannelProvider);
  final results = await Future.wait([
    ch.readSampleRateHz(),
    ch.readWindowMs(),
    ch.readVadThreshold(),
  ]);
  return (
    sampleRateHz: results[0] as int,
    windowMs: results[1] as int,
    vadThreshold: results[2] as double,
  );
});

// ─── Day 27 · live feature vector stream ─────────────────────────────────────

/// Broadcast stream of `AudioFeatures` — one per voiced 450 ms window.
final audioFeatureStreamProvider = StreamProvider<AudioFeatures>((ref) {
  return ref.watch(audioChannelProvider).featureStream;
});

/// Static feature-extractor specs (MFCC count, mel bins, FFT size).
final audioFeatureSpecProvider =
    FutureProvider<({int mfccCount, int melBins, int fftSize})>((ref) async {
  final ch = ref.watch(audioChannelProvider);
  final results = await Future.wait([
    ch.readMfccCount(),
    ch.readMelBins(),
    ch.readFftSize(),
  ]);
  return (
    mfccCount: results[0],
    melBins: results[1],
    fftSize: results[2],
  );
});

// ─── Day 24 — LP4 watchdog ───────────────────────────────────────────────────

final watchdogChannelProvider =
    Provider<WatchdogChannel>((_) => WatchdogChannel());

/// Snapshot of the watchdog's current view of the engine. Refresh to re-read.
final watchdogStatusProvider = FutureProvider<WatchdogStatus>((ref) async {
  return ref.watch(watchdogChannelProvider).readStatus();
});
