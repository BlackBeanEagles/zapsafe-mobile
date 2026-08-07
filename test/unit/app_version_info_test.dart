// Day 324 — AppVersionInfo reads the real pubspec.yaml version at runtime.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/app_version_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load() parses the real pubspec.yaml version + build number', () async {
    final info = await AppVersionInfo.load();
    expect(info.versionName, isNot('unknown'));
    expect(info.raw, contains('+'));
    // pubspec.yaml declares "version: 1.0.0+1" at the time of writing —
    // this assertion pins the real value so a version bump (a real,
    // intentional pubspec.yaml edit) is what breaks this test, not drift.
    expect(info.versionName, '1.0.0');
    expect(info.buildNumber, 1);
  });

  test('kGitCommitHash has a real fallback (not a fabricated hash)', () {
    // In this test run there is no --dart-define=GIT_COMMIT_HASH, so the
    // constant must resolve to the honest not-stamped fallback string.
    expect(kGitCommitHash, contains('not stamped'));
  });
}
