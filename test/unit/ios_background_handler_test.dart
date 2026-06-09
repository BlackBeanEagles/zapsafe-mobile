import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/ios_background_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IosBackgroundHandler channel contract', () {
    test('channel name matches BackgroundProcessingHandler.swift', () {
      // Mirrored at:
      //   ios/Runner/BackgroundProcessingHandler.swift → CHANNEL_NAME
      expect(IosBackgroundHandler.channelName, 'com.zapsafe/ios_background');
    });

    test('method identifiers match the Swift handler switch', () {
      expect(IosBackgroundHandler.methodScheduleNext,   'scheduleNext');
      expect(IosBackgroundHandler.methodCancel,         'cancel');
      expect(IosBackgroundHandler.methodTaskIdentifier, 'taskIdentifier');
      expect(IosBackgroundHandler.methodIsRegistered,   'isRegistered');
    });

    test('task identifier matches BGTaskScheduler registration + Info.plist', () {
      // The Info.plist entry under BGTaskSchedulerPermittedIdentifiers must
      // match this constant byte-for-byte or iOS refuses to register.
      expect(IosBackgroundHandler.taskIdentifier, 'com.zapsafe.dcs');
    });

    test('minimum run gap is 15 minutes per Apple docs', () {
      expect(IosBackgroundHandler.minRunGap, const Duration(minutes: 15));
    });
  });

  group('supported flag', () {
    test('reflects Platform.isIOS at runtime', () {
      final handler = IosBackgroundHandler();
      expect(handler.supported, Platform.isIOS);
    });
  });

  group('off-iOS short-circuit (Windows / Android host)', () {
    test('scheduleNext returns false without invoking channel', () async {
      if (Platform.isIOS) return;
      final h = IosBackgroundHandler();
      expect(await h.scheduleNext(), isFalse);
    });

    test('cancel returns true (no-op) off iOS', () async {
      if (Platform.isIOS) return;
      final h = IosBackgroundHandler();
      expect(await h.cancel(), isTrue);
    });

    test('readTaskIdentifier returns null off iOS', () async {
      if (Platform.isIOS) return;
      final h = IosBackgroundHandler();
      expect(await h.readTaskIdentifier(), isNull);
    });

    test('isRegistered returns false off iOS', () async {
      if (Platform.isIOS) return;
      final h = IosBackgroundHandler();
      expect(await h.isRegistered(), isFalse);
    });
  });

  group('iOS happy path with mock channel', () {
    late List<MethodCall> calls;
    late IosBackgroundHandler handler;
    late MethodChannel channel;

    setUp(() {
      calls = [];
      channel = const MethodChannel(IosBackgroundHandler.channelName);
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case IosBackgroundHandler.methodScheduleNext:   return true;
          case IosBackgroundHandler.methodCancel:         return true;
          case IosBackgroundHandler.methodTaskIdentifier: return IosBackgroundHandler.taskIdentifier;
          case IosBackgroundHandler.methodIsRegistered:   return true;
        }
        return null;
      });
      handler = IosBackgroundHandler(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'scheduleNext invokes the right method and returns true',
      () async {
        final ok = await handler.scheduleNext();
        expect(ok, isTrue);
        expect(calls.single.method, IosBackgroundHandler.methodScheduleNext);
      },
      skip: !Platform.isIOS,
    );

    test(
      'readTaskIdentifier returns the configured constant',
      () async {
        final id = await handler.readTaskIdentifier();
        expect(id, IosBackgroundHandler.taskIdentifier);
      },
      skip: !Platform.isIOS,
    );
  });
}
