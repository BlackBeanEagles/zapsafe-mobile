/// Day 392 — the attributions screen must not drift from the gate.
///
/// `tools/verify_shipped_models.py` holds `TRAINING_DATA`, the single source
/// of truth for which corpora each shipped model was trained on. The screen
/// in `day392_model_attributions_screen.dart` reproduces it for users.
///
/// Two copies of the same facts drift. The realistic failure is not dramatic:
/// a model gets retrained, the gate is updated, and the screen keeps crediting
/// a corpus that is no longer used — or, worse, stops crediting one that is,
/// which for a CC BY corpus means the app quietly stops meeting the licence
/// condition that made it usable commercially in the first place.
///
/// So this test parses the Python table and asserts the two agree exactly, on
/// asset names, corpus names and licence strings. It reads the real file
/// rather than a fixture, because a fixture would drift too.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/presentation/screens/day392_model_attributions_screen.dart';

/// Parses `TRAINING_DATA = { "asset": [("corpus", "licence"), ...], ... }`
/// out of the gate. Comments are stripped first so the long explanatory
/// blocks between entries cannot be mistaken for data.
Map<String, List<(String, String)>> parseGateTable(String src) {
  final start = src.indexOf('TRAINING_DATA = {');
  expect(start, greaterThan(-1), reason: 'TRAINING_DATA not found in gate');

  // Walk to the matching close brace rather than regexing to the first '}',
  // which would stop at the first nested dict.
  var depth = 0;
  var end = -1;
  for (var i = src.indexOf('{', start); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  expect(end, greaterThan(-1), reason: 'unterminated TRAINING_DATA');

  final body = src
      .substring(start, end)
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'\s*#.*$'), ''))
      .join('\n');

  final out = <String, List<(String, String)>>{};
  final entry = RegExp(r'"([^"]+\.tflite)"\s*:\s*\[(.*?)\]', dotAll: true);
  final pair = RegExp(r'\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)');
  for (final m in entry.allMatches(body)) {
    out[m.group(1)!] = pair
        .allMatches(m.group(2)!)
        .map((p) => (p.group(1)!, p.group(2)!))
        .toList();
  }
  return out;
}

void main() {
  late Map<String, List<(String, String)>> gate;

  setUpAll(() {
    final f = File('tools/verify_shipped_models.py');
    expect(f.existsSync(), isTrue,
        reason: 'run from the package root; gate not found at ${f.path}');
    gate = parseGateTable(f.readAsStringSync());
  });

  test('the parser actually found the table', () {
    // Guards the test itself: a regex that silently matches nothing would
    // make every assertion below pass vacuously. That exact bug cost a day
    // when a mangled \b turned a token regex into a no-op and a text model
    // reported 100% OOV with an AUC of exactly 0.5000.
    expect(gate.length, greaterThanOrEqualTo(12));
    expect(gate['m_glass_breaking_v4.tflite'], isNotNull);
    expect(gate['m_glass_breaking_v4.tflite']!.single.$2,
        contains('CC BY'));
  });

  test('every attributed model exists in the gate, with identical corpora',
      () {
    for (final m in kModelAttributions) {
      final rows = gate[m.asset];
      expect(rows, isNotNull,
          reason: '${m.asset} is credited on the attributions screen but has '
              'no entry in TRAINING_DATA. Either it is not shipped, or the '
              'gate is missing provenance for it.');
      expect(m.corpora, equals(rows),
          reason: 'corpora for ${m.asset} differ between the screen and the '
              'gate. The gate is the source of truth — update the screen.');
    }
  });

  test('every real model in the gate is credited on the screen', () {
    final credited = kModelAttributions.map((m) => m.asset).toSet();
    for (final asset in gate.keys) {
      // dcs_fusion is recorded as "n/a - text placeholder, not a model".
      // Crediting a placeholder would be misleading, so it is excluded here
      // rather than given a row.
      if (gate[asset]!.any((c) => c.$2 == 'n/a')) continue;
      expect(credited, contains(asset),
          reason: '$asset is shipped and trained on real data but is not '
              'credited on the attributions screen. For a CC BY corpus this '
              'means the app is not meeting the licence condition.');
    }
  });

  test('FSD50K-trained models are flagged permissive and carry the credit',
      () {
    for (final asset in const [
      'm_glass_breaking_v4.tflite',
      'mg_gunshot_v2.tflite',
    ]) {
      final m = kModelAttributions.firstWhere((x) => x.asset == asset);
      expect(m.isPermissive, isTrue,
          reason: '$asset trains on CC0/CC BY only and must not be listed '
              'as non-commercial');
      expect(m.isNonCommercial, isFalse);
      expect(m.note, contains('CC BY'),
          reason: 'the CC BY obligation is why this screen exists; $asset '
              'should say so');
    }
    expect(kFsd50kCredit, contains('FSD50K'));
    expect(kFsd50kCredit, contains('CC BY 4.0'));
    expect(kFsd50kCredit, contains('Freesound'));
  });

  test('non-commercial models are detected by token, not substring', () {
    // The gate's first version tested `startswith("nc ") || "-nc-"`, which
    // missed "CC BY-NC 3.0" and silently unflagged two models. This asserts
    // the Dart side does not repeat it.
    final nc =
        kModelAttributions.where((m) => m.isNonCommercial).map((m) => m.asset);
    expect(nc, containsAll(const [
      'm5_vocal_stress_v3_38.tflite', // "CC BY-NC-SA 4.0"
      'scream_classifier_v5.tflite', // "CC BY-NC 3.0" via ESC-50
    ]));
    expect(nc.length, 2,
        reason: 'the project is at 2 NC models, down from 5. If this count '
            'changed, the screen copy that says so must change with it.');

    // "research" must not be mistaken for a non-commercial term, and the
    // word "franchise" must not trip a naive substring match for "nc".
    final meld = kModelAttributions
        .firstWhere((m) => m.asset == 'm4_vocal_stress_v3_38.tflite');
    expect(meld.isNonCommercial, isFalse);
    expect(meld.isPermissive, isFalse,
        reason: 'research-use is neither NC nor commercially licensed');
  });
}
