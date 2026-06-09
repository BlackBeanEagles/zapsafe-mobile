import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/native/audio_frame.dart';
import 'package:zapsafe_mobile/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFrame.fromMap', () {
    test('parses a well-formed Map', () {
      final f = AudioFrame.fromMap(const {
        't': 1234567,
        'rms': 512.4,
        'voiced': true,
        'n': 7200,
        'window': 450,
        'thr': 300.0,
      });
      expect(f.timestampMs, 1234567);
      expect(f.rmsEnergy, closeTo(512.4, 1e-6));
      expect(f.voiced, isTrue);
      expect(f.sampleCount, 7200);
      expect(f.windowMs, 450);
      expect(f.threshold, 300);
    });

    test('missing fields default to safe zeros / false', () {
      final f = AudioFrame.fromMap(const {});
      expect(f.timestampMs, 0);
      expect(f.rmsEnergy, 0);
      expect(f.voiced, isFalse);
      expect(f.sampleCount, 0);
      expect(f.windowMs, 0);
      expect(f.threshold, 0);
    });

    test('numeric ints are accepted for double fields', () {
      final f = AudioFrame.fromMap(const {'rms': 600, 'thr': 300});
      expect(f.rmsEnergy, 600.0);
      expect(f.threshold, 300.0);
    });
  });

  group('AudioFrame.normalisedEnergy', () {
    test('zero threshold yields zero (avoid divide-by-zero)', () {
      const f = AudioFrame(
        timestampMs: 0, rmsEnergy: 1000, voiced: true,
        sampleCount: 0, windowMs: 0, threshold: 0,
      );
      expect(f.normalisedEnergy, 0);
    });

    test('at threshold reads 0.25 (1 / 4)', () {
      const f = AudioFrame(
        timestampMs: 0, rmsEnergy: 300, voiced: true,
        sampleCount: 0, windowMs: 0, threshold: 300,
      );
      expect(f.normalisedEnergy, closeTo(0.25, 1e-6));
    });

    test('at 4× threshold reads 1.0 (full bar)', () {
      const f = AudioFrame(
        timestampMs: 0, rmsEnergy: 1200, voiced: true,
        sampleCount: 0, windowMs: 0, threshold: 300,
      );
      expect(f.normalisedEnergy, 1.0);
    });

    test('above 4× threshold clamps to 1.0', () {
      const f = AudioFrame(
        timestampMs: 0, rmsEnergy: 9999, voiced: true,
        sampleCount: 0, windowMs: 0, threshold: 300,
      );
      expect(f.normalisedEnergy, 1.0);
    });

    test('silent frames read 0', () {
      const f = AudioFrame(
        timestampMs: 0, rmsEnergy: 0, voiced: false,
        sampleCount: 0, windowMs: 0, threshold: 300,
      );
      expect(f.normalisedEnergy, 0);
    });
  });

  group('AudioChannel + new channel name (Day 26)', () {
    test('audioEvents channel = audio + ".events"', () {
      expect(PlatformChannelNames.audioEvents,
          '${PlatformChannelNames.audio}.events');
    });

    // Capture is now supported on Android (Day 26) + iOS (Day 28). The
    // "0 off platform" assertions only hold on a host VM where neither is
    // active. On a real device the channel returns real values.
    test('readVadThreshold returns 0 off-platform (host VM)', () async {
      if (Platform.isAndroid || Platform.isIOS) return;
      expect(await AudioChannel().readVadThreshold(), 0);
    });

    test('readSampleRateHz returns 0 off-platform (host VM)', () async {
      if (Platform.isAndroid || Platform.isIOS) return;
      expect(await AudioChannel().readSampleRateHz(), 0);
    });

    test('readWindowMs returns 0 off-platform (host VM)', () async {
      if (Platform.isAndroid || Platform.isIOS) return;
      expect(await AudioChannel().readWindowMs(), 0);
    });

    test('frameStream is empty off-platform (host VM)', () async {
      if (Platform.isAndroid || Platform.isIOS) return;
      final events = await AudioChannel().frameStream.toList();
      expect(events, isEmpty);
    });
  });
}
