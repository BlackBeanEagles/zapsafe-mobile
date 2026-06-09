/// A single country entry used by the phone-number picker.
///
/// Kept tiny on purpose — no `libphonenumber` package dependency. We carry
/// just enough metadata to render the picker, format the number, and
/// validate the length. Full international validation lands when we add
/// a server-side normalizer in Phase 2.
class Country {
  /// ISO 3166-1 alpha-2 code, e.g. `IN`, `US`, `GB`.
  /// Used as the stable identifier across the app (storage, analytics).
  final String iso;

  /// English-language country name shown in the picker.
  final String name;

  /// Native (Hindi/Arabic/etc.) name shown as a subtitle in the picker.
  /// Kept null when there's no useful native form.
  final String? nativeName;

  /// E.164 dial prefix WITHOUT the leading `+`. e.g. `91`, `1`, `971`.
  final String dialCode;

  /// Flag glyph (single emoji codepoint composition). Avoids shipping image
  /// assets — every modern Android/iOS device renders these natively.
  final String flag;

  /// Minimum digits allowed AFTER the dial code. Used to validate length.
  final int minLength;

  /// Maximum digits allowed AFTER the dial code.
  final int maxLength;

  /// Optional first-digit guard. Indian mobile numbers must start with 6-9.
  /// `null` means "any first digit accepted".
  final List<int>? firstDigits;

  const Country({
    required this.iso,
    required this.name,
    this.nativeName,
    required this.dialCode,
    required this.flag,
    required this.minLength,
    required this.maxLength,
    this.firstDigits,
  });

  /// Same number of digits required for both bounds — covers most countries.
  const Country.fixed({
    required String iso,
    required String name,
    String? nativeName,
    required String dialCode,
    required String flag,
    required int length,
    List<int>? firstDigits,
  }) : this(
          iso: iso,
          name: name,
          nativeName: nativeName,
          dialCode: dialCode,
          flag: flag,
          minLength: length,
          maxLength: length,
          firstDigits: firstDigits,
        );

  /// Full E.164 with the leading `+`.
  String e164(String digits) => '+$dialCode$digits';

  /// Returns null if [digits] looks valid for this country, otherwise a
  /// short, user-facing reason. Caller decides whether to show it inline
  /// or only after the user lifts focus.
  String? validate(String digits) {
    if (digits.isEmpty) return null; // empty → don't shout at the user yet
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'Digits only, please.';
    if (digits.length < minLength) return 'Too short for $name.';
    if (digits.length > maxLength) return 'Too long for $name.';
    if (firstDigits != null) {
      final first = int.tryParse(digits[0]);
      if (first == null || !firstDigits!.contains(first)) {
        return 'Must start with ${firstDigits!.join(", ")}.';
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Country && other.iso == iso;

  @override
  int get hashCode => iso.hashCode;
}
