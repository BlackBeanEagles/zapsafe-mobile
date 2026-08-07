/// Day 341 — Real i18n key-coverage helpers.
///
/// Shared by Day 341-343 (per-batch language completion screens), Day 345
/// (the missing-key scanner), and Day 350 (Section J milestone). Loads the
/// actual `assets/translations/*.json` files at runtime via [rootBundle] and
/// diffs their flattened key sets against `en.json` — no hardcoded/fabricated
/// numbers. If a locale file is missing entirely, coverage is reported as 0%
/// with every en.json key listed as missing (not skipped).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Flattens a nested JSON map into `"a.b.c" -> value` pairs, in insertion
/// order. Non-string leaf values are stringified so every en.json leaf is
/// represented.
Map<String, String> flattenJsonMap(Map<String, dynamic> json, [String prefix = '']) {
  final out = <String, String>{};
  for (final entry in json.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      out.addAll(flattenJsonMap(value, key));
    } else {
      out[key] = value?.toString() ?? '';
    }
  }
  return out;
}

/// Loads and flattens `assets/translations/<code>.json`. Returns an empty
/// map (not a throw) if the file does not exist yet, so callers can treat a
/// not-yet-created locale file as "0% coverage" rather than crashing.
Future<Map<String, String>> loadFlatLocale(String code) async {
  try {
    final raw = await rootBundle.loadString('assets/translations/$code.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return flattenJsonMap(decoded);
  } catch (_) {
    return const <String, String>{};
  }
}

/// Real per-locale coverage vs. the given (already-flattened) en.json map.
class LocaleCoverage {
  const LocaleCoverage({
    required this.code,
    required this.totalEnKeys,
    required this.presentCount,
    required this.missingKeys,
  });

  final String code;
  final int totalEnKeys;
  final int presentCount;
  final List<String> missingKeys;

  int get missingCount => missingKeys.length;

  double get pct => totalEnKeys == 0 ? 0 : (presentCount / totalEnKeys) * 100;
}

/// Real directory listing of every `assets/translations/*.json` file bundled
/// with the app, via Flutter's AssetManifest — not a hardcoded list. Returns
/// locale codes (e.g. "hi", "ta"), excluding "en" itself. Used by Day 345's
/// missing-key scanner so it finds genuinely every locale file present,
/// including ones (like ja.json) that exist as drafts but aren't yet in
/// kSupportedLanguages.
Future<List<String>> listTranslationLocaleCodes() async {
  try {
    final manifestRaw = await rootBundle.loadString('AssetManifest.json');
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final codes = <String>[];
    for (final path in manifest.keys) {
      if (!path.startsWith('assets/translations/') || !path.endsWith('.json')) {
        continue;
      }
      final fileName = path.substring('assets/translations/'.length);
      final code = fileName.substring(0, fileName.length - '.json'.length);
      if (code == 'en' || code.isEmpty) continue;
      codes.add(code);
    }
    codes.sort();
    return codes;
  } catch (_) {
    return const <String>[];
  }
}

/// Computes real coverage for [code] by loading its JSON file and diffing
/// keys against [enFlat] (pass the already-flattened en.json map so callers
/// only load en.json once).
Future<LocaleCoverage> computeCoverage(String code, Map<String, String> enFlat) async {
  final flat = await loadFlatLocale(code);
  final missing = <String>[];
  var present = 0;
  for (final key in enFlat.keys) {
    final value = flat[key];
    if (value == null || value.isEmpty) {
      missing.add(key);
    } else {
      present++;
    }
  }
  return LocaleCoverage(
    code: code,
    totalEnKeys: enFlat.length,
    presentCount: present,
    missingKeys: missing,
  );
}
