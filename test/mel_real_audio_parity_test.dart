import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/audio_resampler.dart';
import 'package:zapsafe_mobile/data/services/mel_spectrogram.dart';
import 'package:zapsafe_mobile/data/services/scream_detector_v2.dart';

/// Day 258 — librosa parity on **real audio**, not a synthetic tone.
///
/// `mel_spectrogram_test.dart` proves parity on a two-tone signal. That is a
/// necessary check but a soft one: a pure tone excites a handful of mel bands
/// and leaves most of the spectrogram at the dB floor, so whole classes of
/// error (filterbank edges, dynamic-range handling, the `ref=max`
/// normalisation interacting with real broadband energy) simply do not show up.
///
/// This test runs the pipeline over 3 seconds of a genuine AudioSet clip —
/// `train_wav/3yCuFp1pz2c.wav`, which the shipped m1_scream_v2 scores at
/// 0.9961 — and compares against librosa's own output on the same samples.
///
/// The fixture stores the audio as int16 raw PCM, i.e. exactly the byte
/// layout `com.zapsafe/audio.pcm` delivers, so the quantisation the device
/// imposes is part of what gets compared rather than something the test
/// papers over.
void main() {
  late Map<String, dynamic> golden;
  late Uint8List pcmBytes;

  setUpAll(() {
    golden = jsonDecode(
      File('test/fixtures/mel_golden_real_audio.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    pcmBytes =
        File('test/fixtures/audioset_scream_pcm16.raw').readAsBytesSync();
  });

  List<double> nums(String key) =>
      (golden[key] as List).cast<num>().map((e) => e.toDouble()).toList();

  test('fixture is the clip we think it is', () {
    expect(golden['sr'], 22050);
    expect(golden['n_samples'], ScreamDetectorV2.kSamples);
    expect(pcmBytes.length, ScreamDetectorV2.kSamples * 2,
        reason: 'int16 mono, 3 s at 22050 Hz');
    expect((golden['mel_shape'] as List).first, 128);
    expect((golden['mel_shape'] as List).last, 130);
    expect((golden['model_score'] as num).toDouble(), greaterThan(0.9),
        reason: 'a clip the real model responds strongly to — a fixture the '
            'model ignores would not exercise the interesting dynamic range');
  });

  test('mel matches librosa elementwise on real audio', () {
    final pcm = AudioResampler.pcm16ToDouble(pcmBytes);
    expect(pcm.length, ScreamDetectorV2.kSamples);

    final mel = MelSpectrogram(
      sampleRate: 22050,
      nFft: 2048,
      hopLength: 512,
      nMels: 128,
    ).compute(pcm);

    expect(mel.length, 128);
    expect(mel[0].length, 130);

    void compareRow(String key, int row) {
      final expected = nums(key);
      for (var i = 0; i < expected.length; i++) {
        expect(mel[row][i], closeTo(expected[i], 1e-6),
            reason: '$key[$i] diverged from librosa on real audio');
      }
    }

    // Low, mid and top bands, plus a full time-slice down all 128 bands.
    compareRow('row0', 0);
    compareRow('row40', 40);
    compareRow('row64', 64);
    compareRow('row127', 127);

    final col = nums('col65');
    expect(col.length, 128);
    for (var m = 0; m < col.length; m++) {
      expect(mel[m][65], closeTo(col[m], 1e-6),
          reason: 'col65[$m] diverged from librosa on real audio');
    }
  });

  test('overall mean matches librosa on real audio', () {
    final mel = MelSpectrogram(
      sampleRate: 22050,
      nFft: 2048,
      hopLength: 512,
      nMels: 128,
    ).compute(AudioResampler.pcm16ToDouble(pcmBytes));

    var sum = 0.0, count = 0;
    for (final row in mel) {
      for (final v in row) {
        sum += v;
        count++;
      }
    }
    // Real audio has a mel mean around 0.36 versus ~0.06 for the two-tone
    // signal — most of the spectrogram carries real energy here rather than
    // sitting pinned at the -80 dB floor. That is the point of this fixture.
    expect(sum / count,
        closeTo((golden['mel_mean'] as num).toDouble(), 1e-6));
    expect(sum / count, greaterThan(0.2),
        reason: 'this fixture should exercise broadband energy, not silence');
  });
}
