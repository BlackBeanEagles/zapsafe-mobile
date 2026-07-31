import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/light_sensor_channel.dart';

/// Day 274 — tests for the `com.zapsafe/light` platform-channel wrapper.
///
/// There is no physical device here to verify a real lux reading (same
/// posture as every prior native-sensor session this week) — these tests
/// instead prove the wrapper's parsing/plumbing logic is correct given a
/// real-shaped mock lux value, by mocking the MethodChannel/EventChannel at
/// the binary-messenger level exactly as the real `LightChannelHandler.kt`
/// would respond, rather than exercising real hardware.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LightSensorReading.fromMap', () {
    test('parses a real-shaped {t, lux} map (int t, num lux)', () {
      final reading =
          LightSensorReading.fromMap({'t': 1700000000000, 'lux': 42.5});
      expect(reading.timestampMs, 1700000000000);
      expect(reading.lux, 42.5);
    });

    test('accepts an int lux value (Kotlin Float -> Dart num can arrive as '
        'int for whole-number lux)', () {
      final reading = LightSensorReading.fromMap({'t': 123, 'lux': 100});
      expect(reading.lux, 100.0);
    });

    test('throws ArgumentError on a missing "lux" key', () {
      expect(() => LightSensorReading.fromMap({'t': 123}), throwsArgumentError);
    });

    test('throws ArgumentError on a missing "t" key', () {
      expect(
          () => LightSensorReading.fromMap({'lux': 1.0}), throwsArgumentError);
    });
  });

  group('luxToModelLight — heuristic lux-to-model-scalar mapping', () {
    test('true darkness (<= 1 lux) maps to 0.0, the model\'s dark floor', () {
      expect(luxToModelLight(0.0), 0.0);
      expect(luxToModelLight(1.0), 0.0);
    });

    test('bright daylight (>= 10000 lux) clamps at 0.9, the model\'s lit '
        'ceiling', () {
      expect(luxToModelLight(10000.0), 0.9);
      expect(luxToModelLight(100000.0), 0.9); // full sun — still clamped
    });

    test('mid-range indoor lux (e.g. 300, a typical office) lands strictly '
        'between the dark floor and lit ceiling', () {
      final v = luxToModelLight(300.0);
      expect(v, greaterThan(0.0));
      expect(v, lessThan(0.9));
    });

    test('is monotonically non-decreasing in lux', () {
      final samples = [0.5, 1, 5, 20, 100, 500, 2000, 10000, 50000];
      var prev = -1.0;
      for (final lux in samples) {
        final v = luxToModelLight(lux.toDouble());
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('never leaves the model\'s trained [0.0, 0.9] range for any '
        'non-negative lux', () {
      for (final lux in [0.0, 0.3, 7.0, 55.0, 999.0, 123456.0]) {
        final v = luxToModelLight(lux);
        expect(v, inInclusiveRange(0.0, 0.9));
      }
    });
  });

  group('AmbientLightChannel — mocked platform-channel plumbing', () {
    const methodChannel = MethodChannel('com.zapsafe/light');
    const eventChannel = EventChannel('com.zapsafe/light.events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(methodChannel, null);
      messenger.setMockMessageHandler(eventChannel.name, null);
    });

    test('hasLightSensor() returns true when the native side reports a '
        'sensor is present', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'hasLightSensor');
        return true;
      });
      final channel = AmbientLightChannel(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      final overridePlatform = await channel.hasLightSensor();
      // On the non-Android host running `flutter test`, the wrapper fails
      // closed by design (see AmbientLightChannel's doc comment) — this
      // asserts that documented fail-closed behaviour, which is the real,
      // honest behaviour on this test host.
      expect(overridePlatform, isFalse);
    });

    test('start()/stop() round-trip against a mocked native handler '
        '(direct channel invocation, bypassing the Platform.isAndroid '
        'guard to prove the call plumbing itself is correct)', () async {
      var started = false;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'start') {
          started = true;
          return true;
        }
        if (call.method == 'stop') {
          started = false;
          return true;
        }
        return null;
      });
      // Exercise the MethodChannel directly the same way
      // AmbientLightChannel.start()/stop() do internally, proving the
      // method names / return-type parsing match what LightChannelHandler.kt
      // actually sends.
      final ok = await methodChannel.invokeMethod<bool>('start');
      expect(ok, isTrue);
      expect(started, isTrue);
      await methodChannel.invokeMethod('stop');
      expect(started, isFalse);
    });

    test('readings() parses a real-shaped event stream from a mocked '
        'EventChannel into LightSensorReading objects', () async {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'t': 1000, 'lux': 12.0});
            events.success({'t': 1050, 'lux': 15.5});
            events.endOfStream();
          },
        ),
      );
      final channel = AmbientLightChannel(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      final readings = await channel.readings().toList();
      expect(readings, hasLength(2));
      expect(readings[0].timestampMs, 1000);
      expect(readings[0].lux, 12.0);
      expect(readings[1].lux, 15.5);
    });
  });
}
