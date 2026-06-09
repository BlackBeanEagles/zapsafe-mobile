import 'package:flutter/foundation.dart';

/// Day 38 — provenance of a [GpsSample]. Defaults to [GpsProvider.gps].
/// The fallback coordinator stamps [GpsProvider.cell] / [GpsProvider.wifi]
/// samples whenever the GPS chip can't produce a high-quality fix.
enum GpsProvider {
  gps,
  cell,
  wifi;

  String get wire => switch (this) {
        GpsProvider.gps  => 'gps',
        GpsProvider.cell => 'cell',
        GpsProvider.wifi => 'wifi',
      };

  static GpsProvider fromWire(String? value) => switch (value) {
        'cell' => GpsProvider.cell,
        'wifi' => GpsProvider.wifi,
        _      => GpsProvider.gps,
      };
}

/// Day 37 — one GPS reading. Day 38 extended with a [provider] tag so the
/// fallback layer can surface cell-tower / WiFi estimates without forking
/// the sample stream.
///
/// Field shape matches what the backend's `POST /api/v1/gps/batch/`
/// endpoint expects (timestamp, lat, lng, accuracy_m, speed?, heading?,
/// provider). `geolocator`'s `Position` object maps 1:1 — see
/// [GpsSample.fromMap].
@immutable
class GpsSample {
  /// Wall-clock millis when the OS produced this fix.
  final int timestampMs;

  /// WGS84 latitude.
  final double lat;

  /// WGS84 longitude.
  final double lng;

  /// 1-σ horizontal accuracy in metres. Lower is better; > 50 m is
  /// considered low-quality and triggers the cell-tower fallback (Day 38).
  final double accuracyM;

  /// Optional altitude in metres above sea level. Mostly unreliable
  /// indoors; backend treats null as "unknown".
  final double? altitudeM;

  /// Optional ground speed in m/s.
  final double? speedMps;

  /// Optional heading in degrees from true north [0, 360).
  final double? headingDeg;

  /// Day 38 — which sensor produced this sample. Backwards-compatible
  /// default is [GpsProvider.gps]; cached entries written before Day 38
  /// hydrate to `gps`.
  final GpsProvider provider;

  const GpsSample({
    required this.timestampMs,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    this.altitudeM,
    this.speedMps,
    this.headingDeg,
    this.provider = GpsProvider.gps,
  });

  /// Defensive map parser used both for SharedPreferences round-trips
  /// and for backend response shaping. Missing fields default to 0 /
  /// null so a malformed cache entry never throws.
  factory GpsSample.fromMap(Map<String, dynamic> map) => GpsSample(
        timestampMs: (map['t'] as num?)?.toInt() ?? 0,
        lat:         (map['lat'] as num?)?.toDouble() ?? 0,
        lng:         (map['lng'] as num?)?.toDouble() ?? 0,
        accuracyM:   (map['acc'] as num?)?.toDouble() ?? 0,
        altitudeM:   (map['alt'] as num?)?.toDouble(),
        speedMps:    (map['spd'] as num?)?.toDouble(),
        headingDeg:  (map['hdg'] as num?)?.toDouble(),
        provider:    GpsProvider.fromWire(map['prov'] as String?),
      );

  /// JSON-friendly map. Backend endpoint accepts arrays of these.
  /// `prov` is omitted for plain GPS samples to stay byte-compatible with
  /// pre-Day 38 callers.
  Map<String, dynamic> toMap() => {
        't':   timestampMs,
        'lat': lat,
        'lng': lng,
        'acc': accuracyM,
        if (altitudeM  != null) 'alt': altitudeM,
        if (speedMps   != null) 'spd': speedMps,
        if (headingDeg != null) 'hdg': headingDeg,
        if (provider != GpsProvider.gps) 'prov': provider.wire,
      };

  /// Age of this sample in ms relative to [now]. Negative ages clamp
  /// to 0 (clock skew safety).
  int ageMs({DateTime? now}) {
    final cur = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final age = cur - timestampMs;
    return age < 0 ? 0 : age;
  }

  /// True when the fix is below the LP12 accuracy threshold (50 m).
  bool get isHighQuality => accuracyM > 0 && accuracyM <= 50;

  /// Day 38 — true for samples sourced from a non-GPS provider (cell /
  /// WiFi). UIs colour these differently and the fallback coordinator
  /// uses it to avoid re-triggering itself on its own outputs.
  bool get isFallback => provider != GpsProvider.gps;

  @override
  String toString() =>
      'GpsSample(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} '
      '· ±${accuracyM.toStringAsFixed(1)}m · '
      'src=${provider.wire} · t=$timestampMs)';
}
