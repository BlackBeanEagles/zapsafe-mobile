/// Day 324 — reads the app's real version + build number straight off
/// `pubspec.yaml` at runtime.
///
/// No `package_info_plus` dependency was added for this — `pubspec.yaml`
/// is declared as a Flutter asset (see `pubspec.yaml`'s own `assets:`
/// list) and this class just loads + regex-parses its `version: x.y.z+b`
/// line. This is the *real* source-controlled version string, not a
/// hardcoded Dart copy that can drift from what `flutter build` actually
/// stamps into the release artifact.
library;

import 'package:flutter/services.dart' show rootBundle;

class AppVersionInfo {
  final String versionName; // e.g. "1.0.0"
  final int buildNumber; // e.g. 1
  final String raw; // e.g. "1.0.0+1"

  const AppVersionInfo({
    required this.versionName,
    required this.buildNumber,
    required this.raw,
  });

  static final _versionLine = RegExp(r'^version:\s*(\S+)', multiLine: true);

  /// Loads and parses `pubspec.yaml`. Falls back to a clearly-labelled
  /// "unknown" value (never a fabricated version) if the asset can't be
  /// read or doesn't match the expected `version:` line shape.
  static Future<AppVersionInfo> load() async {
    try {
      final yaml = await rootBundle.loadString('pubspec.yaml');
      final match = _versionLine.firstMatch(yaml);
      final raw = match?.group(1);
      if (raw == null) return _unknown;

      final parts = raw.split('+');
      final versionName = parts.first;
      final buildNumber = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return AppVersionInfo(
        versionName: versionName,
        buildNumber: buildNumber,
        raw: raw,
      );
    } catch (_) {
      return _unknown;
    }
  }

  static const _unknown = AppVersionInfo(
    versionName: 'unknown',
    buildNumber: 0,
    raw: 'unknown (pubspec.yaml asset unreadable)',
  );
}

/// Day 324 — real build-time git commit hash.
///
/// Populated via `--dart-define=GIT_COMMIT_HASH=$(git rev-parse HEAD)` at
/// build time. There is no way to read the git HEAD from inside a running
/// Flutter app without either shelling out (not available on a real
/// device) or a build-time constant — this is the standard real approach.
/// When the build was NOT invoked with that define (e.g. a plain
/// `flutter run` during development, or this analyze/test pass), the
/// fallback string says so explicitly rather than fabricating a hash.
const String kGitCommitHash = String.fromEnvironment(
  'GIT_COMMIT_HASH',
  defaultValue:
      'not stamped — build with --dart-define=GIT_COMMIT_HASH=\$(git rev-parse HEAD)',
);
