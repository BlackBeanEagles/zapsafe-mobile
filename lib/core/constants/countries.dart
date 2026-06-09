import '../../data/models/country.dart';

/// The 14 countries supported in Phase 1.
///
/// India ships first — it's the home market and the only one onboarded
/// during the alpha. The rest are pre-wired so NRI / global users don't
/// hit a country picker without their country.
///
/// Adding more is a one-line addition. Keep the list short enough that the
/// modal sheet scrolls smoothly; we'll switch to a country DB if we ever
/// need ISO 3166's full 250-entry table.
class Countries {
  Countries._();

  /// Default country at first launch. India.
  static const Country defaultCountry = india;

  // ─── India ─ home market, 10-digit mobile numbers, must start 6-9 ─────
  static const india = Country.fixed(
    iso: 'IN',
    name: 'India',
    nativeName: 'भारत',
    dialCode: '91',
    flag: '🇮🇳',
    length: 10,
    firstDigits: [6, 7, 8, 9],
  );

  // ─── United States / Canada — NANP, 10 digits ─────────────────────────
  static const usa = Country.fixed(
    iso: 'US',
    name: 'United States',
    dialCode: '1',
    flag: '🇺🇸',
    length: 10,
  );

  static const canada = Country.fixed(
    iso: 'CA',
    name: 'Canada',
    dialCode: '1',
    flag: '🇨🇦',
    length: 10,
  );

  // ─── United Kingdom — 10 digits, mobiles start with 7 ─────────────────
  static const uk = Country.fixed(
    iso: 'GB',
    name: 'United Kingdom',
    dialCode: '44',
    flag: '🇬🇧',
    length: 10,
  );

  // ─── United Arab Emirates — 9 digits, mobiles start with 5 ────────────
  static const uae = Country(
    iso: 'AE',
    name: 'United Arab Emirates',
    nativeName: 'الإمارات',
    dialCode: '971',
    flag: '🇦🇪',
    minLength: 8,
    maxLength: 9,
  );

  // ─── Singapore — 8 digits ─────────────────────────────────────────────
  static const singapore = Country.fixed(
    iso: 'SG',
    name: 'Singapore',
    dialCode: '65',
    flag: '🇸🇬',
    length: 8,
  );

  // ─── Australia — 9 digits, mobiles start with 4 ───────────────────────
  static const australia = Country.fixed(
    iso: 'AU',
    name: 'Australia',
    dialCode: '61',
    flag: '🇦🇺',
    length: 9,
  );

  // ─── Saudi Arabia — 9 digits ─────────────────────────────────────────
  static const saudi = Country.fixed(
    iso: 'SA',
    name: 'Saudi Arabia',
    nativeName: 'السعودية',
    dialCode: '966',
    flag: '🇸🇦',
    length: 9,
  );

  // ─── Germany — 10-11 digits ───────────────────────────────────────────
  static const germany = Country(
    iso: 'DE',
    name: 'Germany',
    nativeName: 'Deutschland',
    dialCode: '49',
    flag: '🇩🇪',
    minLength: 10,
    maxLength: 11,
  );

  // ─── France — 9 digits ────────────────────────────────────────────────
  static const france = Country.fixed(
    iso: 'FR',
    name: 'France',
    dialCode: '33',
    flag: '🇫🇷',
    length: 9,
  );

  // ─── Bangladesh — 10 digits ───────────────────────────────────────────
  static const bangladesh = Country.fixed(
    iso: 'BD',
    name: 'Bangladesh',
    nativeName: 'বাংলাদেশ',
    dialCode: '880',
    flag: '🇧🇩',
    length: 10,
  );

  // ─── Pakistan — 10 digits ─────────────────────────────────────────────
  static const pakistan = Country.fixed(
    iso: 'PK',
    name: 'Pakistan',
    nativeName: 'پاکستان',
    dialCode: '92',
    flag: '🇵🇰',
    length: 10,
  );

  // ─── Nepal — 10 digits ────────────────────────────────────────────────
  static const nepal = Country.fixed(
    iso: 'NP',
    name: 'Nepal',
    nativeName: 'नेपाल',
    dialCode: '977',
    flag: '🇳🇵',
    length: 10,
  );

  // ─── Sri Lanka — 9 digits ─────────────────────────────────────────────
  static const sriLanka = Country.fixed(
    iso: 'LK',
    name: 'Sri Lanka',
    nativeName: 'ශ්‍රී ලංකා',
    dialCode: '94',
    flag: '🇱🇰',
    length: 9,
  );

  /// All supported countries, in display order (India pinned to top, then
  /// alphabetical by English name).
  static const List<Country> all = [
    india,
    australia,
    bangladesh,
    canada,
    france,
    germany,
    nepal,
    pakistan,
    saudi,
    singapore,
    sriLanka,
    uae,
    uk,
    usa,
  ];

  /// Lookup by ISO code, falls back to [defaultCountry].
  static Country fromIso(String iso) {
    for (final c in all) {
      if (c.iso == iso) return c;
    }
    return defaultCountry;
  }
}
