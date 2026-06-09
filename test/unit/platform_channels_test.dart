import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/background_service.dart';
import 'package:zapsafe_mobile/native/imu_sample.dart';
import 'package:zapsafe_mobile/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformChannelNames registry', () {
    test('every channel name is unique', () {
      final names = <String>{
        PlatformChannelNames.backgroundService,
        PlatformChannelNames.iosBackground,
        PlatformChannelNames.sensors,
        PlatformChannelNames.sensorsEvents,
        PlatformChannelNames.audio,
        PlatformChannelNames.audioEvents,
        PlatformChannelNames.audioFeatures,
        PlatformChannelNames.watchdog,
      };
      // If any were duplicates, the Set would shrink.
      expect(names.length, 8);
    });

    test('backgroundService re-exports BackgroundService.channelName', () {
      expect(PlatformChannelNames.backgroundService,
          BackgroundService.channelName);
    });

    test('sensor channels share a common prefix', () {
      expect(PlatformChannelNames.sensorsEvents,
          '${PlatformChannelNames.sensors}.events');
    });

    test('every channel name follows com.zapsafe/<domain> convention', () {
      for (final name in [
        PlatformChannelNames.backgroundService,
        PlatformChannelNames.iosBackground,
        PlatformChannelNames.sensors,
        PlatformChannelNames.sensorsEvents,
        PlatformChannelNames.audio,
        PlatformChannelNames.audioEvents,
        PlatformChannelNames.audioFeatures,
        PlatformChannelNames.watchdog,
      ]) {
        expect(name, startsWith('com.zapsafe/'));
      }
    });
  });

  group('ImuSample.fromMap', () {
    test('parses a well-formed Map', () {
      final s = ImuSample.fromMap(const {
        't':  1234567,
        'ax': 0.1, 'ay': 0.2, 'az': 9.8,
        'gx': 0.01, 'gy': -0.02, 'gz': 0.03,
      });
      expect(s.timestampMs, 1234567);
      expect(s.ax, closeTo(0.1, 1e-9));
      expect(s.az, closeTo(9.8, 1e-9));
      expect(s.gy, closeTo(-0.02, 1e-9));
    });

    test('missing fields default to 0', () {
      final s = ImuSample.fromMap(const {'t': 100});
      expect(s.timestampMs, 100);
      expect(s.ax, 0);
      expect(s.ay, 0);
      expect(s.az, 0);
      expect(s.gx, 0);
      expect(s.gy, 0);
      expect(s.gz, 0);
    });

    test('numeric ints are accepted alongside doubles', () {
      final s = ImuSample.fromMap(const {
        't': 0, 'ax': 1, 'ay': 2, 'az': 3, 'gx': 4, 'gy': 5, 'gz': 6,
      });
      expect(s.ax, 1.0);
      expect(s.gz, 6.0);
    });

    test('accelMagnitude matches sqrt(x²+y²+z²)', () {
      const s = ImuSample(
        timestampMs: 0, ax: 3, ay: 4, az: 0, gx: 0, gy: 0, gz: 0,
      );
      expect(s.accelMagnitude, closeTo(5.0, 1e-9));
    });

    test('gyroMagnitude matches sqrt(x²+y²+z²)', () {
      const s = ImuSample(
        timestampMs: 0, ax: 0, ay: 0, az: 0, gx: 0, gy: 3, gz: 4,
      );
      expect(s.gyroMagnitude, closeTo(5.0, 1e-9));
    });
  });

  group('SensorChannel · off-platform short-circuit', () {
    test('supported reflects Platform.isAndroid', () {
      expect(SensorChannel().supported, Platform.isAndroid);
    });

    test('start returns false without channel call off Android', () async {
      if (Platform.isAndroid) return;
      expect(await SensorChannel().start(), isFalse);
    });

    test('stop returns true (no-op) off Android', () async {
      if (Platform.isAndroid) return;
      expect(await SensorChannel().stop(), isTrue);
    });

    test('stream is empty off Android', () async {
      if (Platform.isAndroid) return;
      final events = await SensorChannel().stream.toList();
      expect(events, isEmpty);
    });
  });

  group('AudioChannel · off-platform short-circuit', () {
    test('supported reflects Platform.isAndroid', () {
      expect(AudioChannel().supported, Platform.isAndroid);
    });

    test('start returns false off Android', () async {
      if (Platform.isAndroid) return;
      expect(await AudioChannel().start(), isFalse);
    });

    test('stop returns true (no-op) off Android', () async {
      if (Platform.isAndroid) return;
      expect(await AudioChannel().stop(), isTrue);
    });

    test('isRecording returns false off Android', () async {
      if (Platform.isAndroid) return;
      expect(await AudioChannel().isRecording(), isFalse);
    });
  });
}
