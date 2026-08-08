import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/native/audio_features.dart';
import 'package:zapsafe_mobile/native/platform_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFeatures.fromMap', () {
    test('parses a well-formed Map', () {
      final f = AudioFeatures.fromMap(const {
        't': 1234567,
        'mfcc': [0.1, -0.2, 3.0, -4.5, 5.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        'zcr': 0.123,
        'centroid': 1834.7,
      });
      expect(f.timestampMs, 1234567);
      expect(f.mfcc.length, 13);
      expect(f.mfcc[0], closeTo(0.1, 1e-9));
      expect(f.mfcc[3], closeTo(-4.5, 1e-9));
      expect(f.zcr, closeTo(0.123, 1e-9));
      expect(f.spectralCentroidHz, closeTo(1834.7, 1e-9));
    });

    test('missing fields default to zero / empty', () {
      final f = AudioFeatures.fromMap(const {});
      expect(f.timestampMs, 0);
      expect(f.mfcc, isEmpty);
      expect(f.zcr, 0);
      expect(f.spectralCentroidHz, 0);
    });

    test('numeric ints are accepted for double fields', () {
      final f = AudioFeatures.fromMap(const {
        'mfcc': [1, 2, 3],
        'zcr': 0,
        'centroid': 1500,
      });
      expect(f.mfcc, [1.0, 2.0, 3.0]);
      expect(f.spectralCentroidHz, 1500.0);
    });

    test('non-list mfcc entries become 0', () {
      final f = AudioFeatures.fromMap(const {
        'mfcc': ['abc', 1.0, null, 2.5],
      });
      expect(f.mfcc, [0.0, 1.0, 0.0, 2.5]);
    });

    test('mfcc list is unmodifiable', () {
      final f = AudioFeatures.fromMap(const {'mfcc': [1, 2, 3]});
      expect(() => f.mfcc.add(0), throwsUnsupportedError);
    });
  });

  group('AudioFeatures helpers', () {
    test('dimension = mfcc.length + 2 (zcr + centroid)', () {
      final f = AudioFeatures.fromMap(const {
        'mfcc': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      });
      expect(f.dimension, 15);
    });

    test('toFloat32Tensor packs mfcc then zcr then centroid', () {
      const f = AudioFeatures(
        timestampMs: 0,
        mfcc: [1.0, 2.0, 3.0],
        zcr: 0.5,
        spectralCentroidHz: 1234.0,
      );
      final tensor = f.toFloat32Tensor();
      expect(tensor, isA<Float32List>());
      expect(tensor.length, 5);
      expect(tensor[0], 1.0);
      expect(tensor[1], 2.0);
      expect(tensor[2], 3.0);
      expect(tensor[3], 0.5);
      expect(tensor[4], 1234.0);
    });

    test('toFloat32Tensor on empty-mfcc produces a 2-element tensor', () {
      const f = AudioFeatures(
        timestampMs: 0, mfcc: [], zcr: 0.1, spectralCentroidHz: 800,
      );
      final tensor = f.toFloat32Tensor();
      expect(tensor.length, 2);
      // Float32 doesn't represent 0.1 exactly — use a small epsilon.
      expect(tensor[0], closeTo(0.1, 1e-6));
      expect(tensor[1], 800.0);
    });
  });

  group('Channel registry · Day 27 additions', () {
    test('audioFeatures channel exists and is unique', () {
      expect(PlatformChannelNames.audioFeatures, 'com.zapsafe/audio.features');
      final all = <String>{
        PlatformChannelNames.backgroundService,
        PlatformChannelNames.iosBackground,
        PlatformChannelNames.sensors,
        PlatformChannelNames.sensorsEvents,
        PlatformChannelNames.audio,
        PlatformChannelNames.audioEvents,
        PlatformChannelNames.audioFeatures,
        PlatformChannelNames.watchdog,
      };
      expect(all.length, 8);
    });
  });

  group('AudioChannel · Day 27 off-platform short-circuits', () {
    test('readMfccCount returns 0 off Android', () async {
      if (Platform.isAndroid) return;
      expect(await AudioChannel().readMfccCount(), 0);
    });

    test('readMelBins returns 0 off Android', () async {
      if (Platform.isAndroid) return;
      expect(await AudioChannel().readMelBins(), 0);
    });

    test('readFftSize returns 0 off Android', () async {
      if (Platform.isAndroid) return;
      expect(await AudioChannel().readFftSize(), 0);
    });

    test('featureStream is empty off Android', () async {
      if (Platform.isAndroid) return;
      final events = await AudioChannel().featureStream.toList();
      expect(events, isEmpty);
    });
  });
}
