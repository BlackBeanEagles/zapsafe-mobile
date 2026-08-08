import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/audio_resampler.dart';
import 'package:zapsafe_mobile/data/services/scream_detector_v2.dart';
import 'package:zapsafe_mobile/native/pcm_window.dart';

/// Day 258 — the capture -> model handoff.
///
/// `ScreamAudioPipeline` itself needs a loaded `ScreamDetectorV2`, which needs
/// native TFLite, so the pipeline's own inference path is not host-testable.
/// What *is* testable — and is where the silent breakage lives — is the
/// contract on the payload crossing the platform channel: byte order, sample
/// rate handling, window length, and the fact that the samples are raw.
void main() {
  /// Builds the exact map `AudioChannelHandler.emitPcmWindow` sends.
  Map<String, Object> nativeEvent({
    required int sampleRateHz,
    required int samples,
    double freq = 440,
    int timestampMs = 1234,
  }) {
    final bytes = Uint8List(samples * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < samples; i++) {
      final v = math.sin(2 * math.pi * freq * (i / sampleRateHz));
      view.setInt16(i * 2, (v * 20000).round(), Endian.little);
    }
    return {'t': timestampMs, 'sr': sampleRateHz, 'pcm': bytes};
  }

  group('PcmWindow parsing', () {
    test('decodes the native event map', () {
      final w = PcmWindow.fromMap(
          nativeEvent(sampleRateHz: 22050, samples: 66150));
      expect(w.timestampMs, 1234);
      expect(w.sampleRateHz, 22050);
      expect(w.sampleCount, 66150);
      expect(w.isUsable, isTrue);
    });

    test('a 22050Hz window needs no resampling and keeps all 66150 samples',
        () {
      final w = PcmWindow.fromMap(
          nativeEvent(sampleRateHz: 22050, samples: 66150));
      final s = w.samples(targetRateHz: ScreamDetectorV2.kSampleRate);
      expect(s.length, ScreamDetectorV2.kSamples,
          reason: 'exactly 3 s, no padding or truncation needed');
    });

    test('a 44100Hz window resamples to 22050 and lands on 3 s', () {
      // The device fallback path: 6 s of samples at 44.1 kHz is 3 s of audio.
      final w = PcmWindow.fromMap(
          nativeEvent(sampleRateHz: 44100, samples: 66150 * 2));
      expect(w.sampleCount, 132300);
      final s = w.samples(targetRateHz: ScreamDetectorV2.kSampleRate);
      expect(s.length, ScreamDetectorV2.kSamples,
          reason: '132300 samples at 44.1kHz -> 66150 at 22.05kHz');
    });

    test('rejects a window with an unknown sample rate', () {
      // Rate 0 must never be treated as "probably the model's rate".
      final w = PcmWindow.fromMap(
          {'t': 1, 'sr': 0, 'pcm': Uint8List(64)});
      expect(w.isUsable, isFalse);
      expect(w.samples(targetRateHz: 22050), isEmpty);
    });

    test('survives a malformed event without throwing', () {
      final w = PcmWindow.fromMap(const {});
      expect(w.isUsable, isFalse);
      expect(w.sampleCount, 0);
      expect(w.rms, 0.0);
    });

    test('reads little-endian, not big-endian', () {
      // 0x0100 LE = 256. Read as BE it would be 1 — a 256x amplitude error
      // that a min-max normalised mel would completely hide.
      final w = PcmWindow.fromMap({
        't': 0,
        'sr': 22050,
        'pcm': Uint8List.fromList([0x00, 0x01]),
      });
      final s = w.samples(targetRateHz: 22050);
      expect(s.first, closeTo(256 / 32768, 1e-12));
    });
  });

  group('samples are raw, not pre-windowed', () {
    // AudioCaptureService applies a Hann taper in place for the legacy MFCC
    // path. If the mel path ever picks up those mutated samples, the signal
    // gets windowed twice — once by Kotlin, once per STFT frame by
    // MelSpectrogram. The result has the right shape and range and is wrong.
    test('a constant tone has near-constant envelope across the window', () {
      final w = PcmWindow.fromMap(
          nativeEvent(sampleRateHz: 22050, samples: 66150));
      final s = w.samples(targetRateHz: 22050);

      double peakIn(int from, int to) {
        var p = 0.0;
        for (var i = from; i < to; i++) {
          p = math.max(p, s[i].abs());
        }
        return p;
      }

      final edge = peakIn(0, 2000);
      final centre = peakIn(32000, 34000);
      // Under a Hann taper the first 2000 samples would peak near zero
      // while the centre peaks at full amplitude.
      expect(edge, closeTo(centre, 0.02),
          reason: 'the window edge is attenuated — samples arrived '
              'Hann-tapered and will be windowed twice');
    });
  });

  group('resampler is applied end to end', () {
    test('a 17kHz tone at 44.1kHz does not alias into the output', () {
      final w = PcmWindow.fromMap(nativeEvent(
          sampleRateHz: 44100, samples: 66150 * 2, freq: 17000));
      final s = w.samples(targetRateHz: 22050);
      var energy = 0.0;
      for (final v in s) {
        energy += v * v;
      }
      expect(math.sqrt(energy / s.length), lessThan(0.02),
          reason: '17kHz survived resampling to 22.05kHz — it has aliased '
              'to ~5kHz and is now indistinguishable from real content');
    });
  });

  group('rms silence gate', () {
    test('silence reads ~0 and speech-level audio reads well above the gate',
        () {
      final silent = PcmWindow(
        timestampMs: 0,
        sampleRateHz: 22050,
        pcmBytes: Uint8List(66150 * 2),
      );
      expect(silent.rms, 0.0);

      final loud = PcmWindow.fromMap(
          nativeEvent(sampleRateHz: 22050, samples: 66150));
      // 20000/32768 amplitude sine -> rms = amp / sqrt(2) ~= 0.43
      expect(loud.rms, greaterThan(0.3));
    });
  });

  group('scipy parity holds through the channel payload', () {
    test('pcm16ToDouble + resample equals the resampler used directly', () {
      final map = nativeEvent(sampleRateHz: 44100, samples: 4096);
      final w = PcmWindow.fromMap(map);
      final viaWindow = w.samples(targetRateHz: 22050);
      final direct = AudioResampler.resample(
        AudioResampler.pcm16ToDouble(map['pcm'] as Uint8List),
        44100,
        22050,
      );
      expect(viaWindow.length, direct.length);
      for (var i = 0; i < direct.length; i++) {
        expect(viaWindow[i], direct[i]);
      }
    });
  });
}
