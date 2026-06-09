import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchdogChannel constants', () {
    test('channel name is com.zapsafe/watchdog', () {
      expect(PlatformChannelNames.watchdog, 'com.zapsafe/watchdog');
    });

    test('default LP4 threshold is 30 seconds', () {
      expect(WatchdogChannel.defaultThresholdMs, 30000);
    });

    test('supported reflects Platform.isAndroid', () {
      expect(WatchdogChannel().supported, Platform.isAndroid);
    });
  });

  group('WatchdogStatus.isStale', () {
    test('null heartbeat is stale (never written = service never started)', () {
      const s = WatchdogStatus(
        lastHeartbeatMs: null,
        secondsSinceLastPing: null,
        thresholdMs: 30000,
      );
      expect(s.isStale, isTrue);
    });

    test('within threshold → fresh', () {
      const s = WatchdogStatus(
        lastHeartbeatMs: 1000,
        secondsSinceLastPing: 5,
        thresholdMs: 30000,
      );
      expect(s.isStale, isFalse);
    });

    test('exactly at threshold → still fresh', () {
      const s = WatchdogStatus(
        lastHeartbeatMs: 1000,
        secondsSinceLastPing: 30,
        thresholdMs: 30000,
      );
      // 30 seconds × 1000 = 30000 ms — not > threshold.
      expect(s.isStale, isFalse);
    });

    test('beyond threshold → stale', () {
      const s = WatchdogStatus(
        lastHeartbeatMs: 1000,
        secondsSinceLastPing: 31,
        thresholdMs: 30000,
      );
      expect(s.isStale, isTrue);
    });

    test('a long-dead engine is stale', () {
      const s = WatchdogStatus(
        lastHeartbeatMs: 1000,
        secondsSinceLastPing: 600,
        thresholdMs: 30000,
      );
      expect(s.isStale, isTrue);
    });
  });

  group('WatchdogChannel · off-platform short-circuit', () {
    test('enqueue returns false off Android', () async {
      if (Platform.isAndroid) return;
      expect(await WatchdogChannel().enqueue(), isFalse);
    });

    test('cancel returns true (no-op) off Android', () async {
      if (Platform.isAndroid) return;
      expect(await WatchdogChannel().cancel(), isTrue);
    });

    test('readStatus returns a stale-default snapshot off Android', () async {
      if (Platform.isAndroid) return;
      final s = await WatchdogChannel().readStatus();
      expect(s.lastHeartbeatMs, isNull);
      expect(s.secondsSinceLastPing, isNull);
      expect(s.thresholdMs, WatchdogChannel.defaultThresholdMs);
      expect(s.isStale, isTrue);
    });

    test('isEnqueued returns false off Android (Day 25)', () async {
      if (Platform.isAndroid) return;
      expect(await WatchdogChannel().isEnqueued(), isFalse);
    });
  });
}
