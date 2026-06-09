import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundService channel contract', () {
    late List<MethodCall> calls;
    late BackgroundService service;
    late MethodChannel channel;

    setUp(() {
      calls = [];
      channel = const MethodChannel(BackgroundService.channelName);
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case BackgroundService.methodStart:    return true;
          case BackgroundService.methodStop:     return true;
          case BackgroundService.methodIsRunning: return true;
        }
        return null;
      });
      service = BackgroundService(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('channel name matches the constant the native side mirrors', () {
      expect(BackgroundService.channelName, 'com.zapsafe/background_service');
    });

    test('method identifiers match the native MainActivity switch', () {
      expect(BackgroundService.methodStart,     'start');
      expect(BackgroundService.methodStop,      'stop');
      expect(BackgroundService.methodIsRunning, 'isRunning');
    });

    test('supported returns true on Android, false elsewhere', () {
      expect(service.supported, Platform.isAndroid);
    });
  });

  group('start / stop / refresh — happy path (Android only)', () {
    late List<MethodCall> calls;
    late BackgroundService service;
    late MethodChannel channel;

    setUp(() {
      calls = [];
      channel = const MethodChannel(BackgroundService.channelName);
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      service = BackgroundService(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'start invokes "start" and caches running=true',
      () async {
        final ok = await service.start();
        expect(ok, isTrue);
        expect(service.isRunning, isTrue);
        expect(calls.single.method, BackgroundService.methodStart);
      },
      skip: !Platform.isAndroid,
    );

    test(
      'stop invokes "stop" and clears running flag',
      () async {
        await service.start();
        final ok = await service.stop();
        expect(ok, isTrue);
        expect(service.isRunning, isFalse);
        expect(calls.last.method, BackgroundService.methodStop);
      },
      skip: !Platform.isAndroid,
    );

    test(
      'refresh queries the native side and updates the cached flag',
      () async {
        final running = await service.refresh();
        expect(running, isTrue);
        expect(service.isRunning, isTrue);
        expect(calls.last.method, BackgroundService.methodIsRunning);
      },
      skip: !Platform.isAndroid,
    );
  });

  group('start handles native errors gracefully', () {
    late BackgroundService service;
    late MethodChannel channel;

    setUp(() {
      channel = const MethodChannel(BackgroundService.channelName);
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'SERVICE_FAIL', message: 'simulated');
      });
      service = BackgroundService(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'returns false and leaves running=false when start throws',
      () async {
        final ok = await service.start();
        expect(ok, isFalse);
        expect(service.isRunning, isFalse);
      },
      skip: !Platform.isAndroid,
    );
  });

  group('off-Android path', () {
    test('off-Android: start returns false without invoking channel',
        () async {
      if (Platform.isAndroid) return;
      // Construct a fresh service with no channel handler set up. The
      // off-Android branch should short-circuit before touching the channel.
      final service = BackgroundService();
      final ok = await service.start();
      expect(ok, isFalse);
      expect(service.isRunning, isFalse);
    });

    test('off-Android: stop returns true and running stays false', () async {
      if (Platform.isAndroid) return;
      final service = BackgroundService();
      final ok = await service.stop();
      expect(ok, isTrue);
      expect(service.isRunning, isFalse);
    });

    test('off-Android: refresh returns false', () async {
      if (Platform.isAndroid) return;
      final service = BackgroundService();
      final running = await service.refresh();
      expect(running, isFalse);
      expect(service.isRunning, isFalse);
    });
  });
}
