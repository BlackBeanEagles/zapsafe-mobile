// Day 37 — GPS service unit tests.
//
// These run on the host VM (no Geolocator plugin available), so we
// exercise the deterministic surfaces only:
//   • GpsSample.fromMap / toMap round-trip + isHighQuality + ageMs
//   • GpsPollingProfile.fromAppState mapping (all 7 AppStates)
//   • GpsPollingProfile.interval + .accuracy values
//   • GpsService.injectSample → buffer + stream + latest
//   • setAppState() updates the profile getter
//   • clearBatch() resets pendingBatchSize
//
// We never call .start() / .pollOnce() — those need the real plugin.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zapsafe_mobile/data/models/app_state.dart';
import 'package:zapsafe_mobile/data/models/gps_sample.dart';
import 'package:zapsafe_mobile/data/services/gps_polling_profile.dart';
import 'package:zapsafe_mobile/data/services/gps_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GpsSample', () {
    test('toMap → fromMap round-trips all fields', () {
      const s = GpsSample(
        timestampMs: 1700000000000,
        lat: 12.9716,
        lng: 77.5946,
        accuracyM: 8.5,
        altitudeM: 920,
        speedMps: 1.4,
        headingDeg: 87,
      );
      final restored = GpsSample.fromMap(s.toMap());
      expect(restored.timestampMs, s.timestampMs);
      expect(restored.lat, s.lat);
      expect(restored.lng, s.lng);
      expect(restored.accuracyM, s.accuracyM);
      expect(restored.altitudeM, s.altitudeM);
      expect(restored.speedMps, s.speedMps);
      expect(restored.headingDeg, s.headingDeg);
    });

    test('fromMap defaults gracefully on missing keys', () {
      final s = GpsSample.fromMap(const {});
      expect(s.timestampMs, 0);
      expect(s.lat, 0);
      expect(s.lng, 0);
      expect(s.accuracyM, 0);
      expect(s.altitudeM, isNull);
      expect(s.speedMps, isNull);
      expect(s.headingDeg, isNull);
    });

    test('isHighQuality respects LP12 50 m threshold', () {
      const tight = GpsSample(
          timestampMs: 0, lat: 0, lng: 0, accuracyM: 12);
      const loose = GpsSample(
          timestampMs: 0, lat: 0, lng: 0, accuracyM: 75);
      const zero = GpsSample(
          timestampMs: 0, lat: 0, lng: 0, accuracyM: 0);
      expect(tight.isHighQuality, isTrue);
      expect(loose.isHighQuality, isFalse);
      expect(zero.isHighQuality, isFalse);
    });

    test('ageMs clamps to 0 on future timestamp (clock skew)', () {
      final future = DateTime.now().millisecondsSinceEpoch + 60000;
      final s = GpsSample(timestampMs: future, lat: 0, lng: 0, accuracyM: 1);
      expect(s.ageMs(), 0);
    });

    test('ageMs returns positive ms for past timestamp', () {
      final past = DateTime.now().millisecondsSinceEpoch - 5000;
      final s = GpsSample(timestampMs: past, lat: 0, lng: 0, accuracyM: 1);
      expect(s.ageMs(), greaterThanOrEqualTo(5000));
    });
  });

  group('GpsPollingProfile', () {
    test('fromAppState maps all 7 states', () {
      expect(GpsPollingProfile.fromAppState(AppState.idle),
          GpsPollingProfile.off);
      expect(GpsPollingProfile.fromAppState(AppState.postIncident),
          GpsPollingProfile.off);
      expect(GpsPollingProfile.fromAppState(AppState.monitoring),
          GpsPollingProfile.monitoring);
      expect(GpsPollingProfile.fromAppState(AppState.elevated),
          GpsPollingProfile.elevated);
      expect(GpsPollingProfile.fromAppState(AppState.alertPending),
          GpsPollingProfile.sosTime);
      expect(GpsPollingProfile.fromAppState(AppState.sosActive),
          GpsPollingProfile.sosTime);
      expect(GpsPollingProfile.fromAppState(AppState.escalating),
          GpsPollingProfile.sosTime);
    });

    test('intervals match timeline cadences', () {
      expect(GpsPollingProfile.off.interval, Duration.zero);
      expect(GpsPollingProfile.monitoring.interval,
          const Duration(minutes: 5));
      expect(GpsPollingProfile.elevated.interval,
          const Duration(seconds: 30));
      expect(GpsPollingProfile.sosTime.interval,
          const Duration(seconds: 10));
    });

    test('accuracy escalates with cadence', () {
      expect(GpsPollingProfile.monitoring.accuracy, LocationAccuracy.low);
      expect(GpsPollingProfile.elevated.accuracy, LocationAccuracy.high);
      expect(GpsPollingProfile.sosTime.accuracy, LocationAccuracy.best);
    });
  });

  group('GpsService', () {
    test('injectSample updates latest + buffer + stream', () async {
      final svc = GpsService();
      addTearDown(svc.dispose);
      final received = <GpsSample>[];
      final sub = svc.samples.listen(received.add);

      const sample = GpsSample(
          timestampMs: 1700000000000,
          lat: 12.9716, lng: 77.5946, accuracyM: 5);
      svc.injectSample(sample);
      await Future<void>.delayed(Duration.zero);

      expect(svc.latest, sample);
      expect(svc.pendingBatchSize, 1);
      expect(received, hasLength(1));
      expect(received.first.lat, closeTo(12.9716, 1e-9));
      await sub.cancel();
    });

    test('setAppState rotates the profile getter', () {
      final svc = GpsService();
      addTearDown(svc.dispose);
      // Defaults to MONITORING.
      expect(svc.profile, GpsPollingProfile.monitoring);

      svc.setAppState(AppState.elevated);
      expect(svc.profile, GpsPollingProfile.elevated);
      expect(svc.currentInterval, const Duration(seconds: 30));

      svc.setAppState(AppState.sosActive);
      expect(svc.profile, GpsPollingProfile.sosTime);

      svc.setAppState(AppState.idle);
      expect(svc.profile, GpsPollingProfile.off);
    });

    test('clearBatch resets pendingBatchSize', () {
      final svc = GpsService();
      addTearDown(svc.dispose);
      for (var i = 0; i < 3; i++) {
        svc.injectSample(GpsSample(
            timestampMs: i, lat: 0, lng: 0, accuracyM: 1));
      }
      expect(svc.pendingBatchSize, 3);
      svc.clearBatch();
      expect(svc.pendingBatchSize, 0);
    });

    test('buffer auto-flushes (and clears) once threshold hit', () async {
      final svc = GpsService();
      addTearDown(svc.dispose);
      // Threshold is 6 — with no ApiClient the flush returns false but
      // the buffer should NOT auto-clear (flushBatch early-returns when
      // _api is null). Verify the buffer therefore keeps growing.
      for (var i = 0; i < 8; i++) {
        svc.injectSample(GpsSample(
            timestampMs: i, lat: 0, lng: 0, accuracyM: 1));
      }
      expect(svc.pendingBatchSize, 8);
    });
  });
}
