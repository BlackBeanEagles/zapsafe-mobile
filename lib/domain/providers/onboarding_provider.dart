import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Contact model ────────────────────────────────────────────────────────────

/// A single emergency contact collected during onboarding.
class OnboardingContact {
  const OnboardingContact({
    required this.tier,
    required this.name,
    required this.phone,
  });

  /// 1 = first responder / most trusted, 2 = close trusted, 3 = backup.
  final int tier;
  final String name;
  final String phone;

  bool get isValid => name.trim().isNotEmpty && phone.trim().length >= 7;

  OnboardingContact copyWith({String? name, String? phone}) =>
      OnboardingContact(
        tier: tier,
        name: name ?? this.name,
        phone: phone ?? this.phone,
      );

  @override
  String toString() => 'OnboardingContact(tier:$tier name:$name phone:$phone)';
}

// ─── Location model ───────────────────────────────────────────────────────────

/// A trusted location pre-seeded during onboarding (feeds LP24 auto-learn).
class OnboardingLocation {
  const OnboardingLocation({required this.label, this.customName = ''});

  /// Preset labels — shown as quick-add chips in Step 3.
  static const presets = ['Home', 'Work', 'Gym', 'School'];

  /// 'Home', 'Work', 'Gym', 'School', or 'Custom'.
  final String label;

  /// Non-empty only when [label] == 'Custom'.
  final String customName;

  /// Display name shown in the list.
  String get displayName => label == 'Custom'
      ? (customName.trim().isEmpty ? 'Custom' : customName.trim())
      : label;

  /// A custom location is valid only when its customName is filled.
  bool get isValid =>
      label != 'Custom' || customName.trim().isNotEmpty;

  OnboardingLocation copyWith({String? label, String? customName}) =>
      OnboardingLocation(
        label: label ?? this.label,
        customName: customName ?? this.customName,
      );

  @override
  String toString() => 'OnboardingLocation($label / $customName)';
}

// ─── Accessibility model ──────────────────────────────────────────────────────

/// Accessibility preferences collected in Step 4.
/// Feeds LP20 prosodic baseline + accessibility backend settings (Days 106+).
class OnboardingAccessibility {
  const OnboardingAccessibility({
    this.language = 'en',
    this.simpleMode = false,
    this.highContrast = false,
    this.fontScale = 1.0,
  });

  /// BCP-47 language code. LP20 APAC baselines: en/hi/ta/te/kn/bn/id.
  final String language;

  /// Simplified UI — single large SOS button, no swipe combos (LP elderly mode).
  final bool simpleMode;

  /// WCAG AAA high-contrast palette.
  final bool highContrast;

  /// Text scale multiplier: 1.0 (normal) → 2.0 (largest).
  final double fontScale;

  static const supportedLanguages = <Map<String, String>>[
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'te', 'name': 'Telugu'},
    {'code': 'kn', 'name': 'Kannada'},
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'id', 'name': 'Indonesian'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'de', 'name': 'German'},
  ];

  String get languageName =>
      supportedLanguages.firstWhere(
        (l) => l['code'] == language,
        orElse: () => {'code': language, 'name': language},
      )['name'] ??
      language;

  OnboardingAccessibility copyWith({
    String? language,
    bool? simpleMode,
    bool? highContrast,
    double? fontScale,
  }) =>
      OnboardingAccessibility(
        language: language ?? this.language,
        simpleMode: simpleMode ?? this.simpleMode,
        highContrast: highContrast ?? this.highContrast,
        fontScale: fontScale ?? this.fontScale,
      );

  @override
  String toString() =>
      'OnboardingAccessibility(lang:$language simple:$simpleMode hc:$highContrast scale:$fontScale)';
}

// ─── State ────────────────────────────────────────────────────────────────────

/// Tracks progress through the 5-step onboarding flow (Days 41-45).
class OnboardingState {
  const OnboardingState({
    this.termsAccepted = false,
    this.currentStep = 1,
    this.completed = false,
    this.contacts = const [],
    this.locations = const [],
    this.accessibility = const OnboardingAccessibility(),
  });

  final bool termsAccepted;
  final int currentStep; // 1-5
  final bool completed;
  final List<OnboardingContact> contacts;
  final List<OnboardingLocation> locations;
  final OnboardingAccessibility accessibility;

  static const maxLocations = 5;

  /// True when at least one Tier-1 contact has a valid name + phone.
  bool get hasRequiredContact =>
      contacts.any((c) => c.tier == 1 && c.isValid);

  List<OnboardingContact> tier(int t) =>
      contacts.where((c) => c.tier == t).toList();

  /// True when [label] is already in the locations list (prevents duplicates
  /// for the preset quick-add chips).
  bool hasLocation(String label) =>
      locations.any((l) => l.label == label);

  OnboardingState copyWith({
    bool? termsAccepted,
    int? currentStep,
    bool? completed,
    List<OnboardingContact>? contacts,
    List<OnboardingLocation>? locations,
    OnboardingAccessibility? accessibility,
  }) =>
      OnboardingState(
        termsAccepted: termsAccepted ?? this.termsAccepted,
        currentStep: currentStep ?? this.currentStep,
        completed: completed ?? this.completed,
        contacts: contacts ?? this.contacts,
        locations: locations ?? this.locations,
        accessibility: accessibility ?? this.accessibility,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  // Step 1
  void acceptTerms() => state = state.copyWith(termsAccepted: true);
  void rejectTerms() => state = state.copyWith(termsAccepted: false);

  // Navigation
  void advanceToStep(int step) {
    assert(step >= 1 && step <= 5);
    state = state.copyWith(currentStep: step);
  }

  // Step 2 — contacts
  /// Adds a new blank slot for [tier] if the per-tier cap is not reached.
  /// Tier 1: max 1 · Tier 2: max 2 · Tier 3: max 2.
  void addContact(int tier) {
    final caps = {1: 1, 2: 2, 3: 2};
    final current = state.tier(tier);
    if (current.length >= (caps[tier] ?? 2)) return;
    final updated = [...state.contacts, OnboardingContact(tier: tier, name: '', phone: '')];
    state = state.copyWith(contacts: updated);
  }

  /// Replaces the contact at [index] in the full list with [updated].
  void updateContact(int index, OnboardingContact updated) {
    final list = [...state.contacts];
    if (index < 0 || index >= list.length) return;
    list[index] = updated;
    state = state.copyWith(contacts: list);
  }

  /// Removes the contact at [index] in the full list.
  void removeContact(int index) {
    final list = [...state.contacts];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    state = state.copyWith(contacts: list);
  }

  // Step 4 — accessibility
  void setLanguage(String code) => state = state.copyWith(
        accessibility: state.accessibility.copyWith(language: code),
      );

  void setSimpleMode(bool v) => state = state.copyWith(
        accessibility: state.accessibility.copyWith(simpleMode: v),
      );

  void setHighContrast(bool v) => state = state.copyWith(
        accessibility: state.accessibility.copyWith(highContrast: v),
      );

  void setFontScale(double v) => state = state.copyWith(
        accessibility: state.accessibility.copyWith(
          fontScale: v.clamp(1.0, 2.0),
        ),
      );

  // Step 3 — trusted locations
  /// Adds a preset quick-add chip location (Home / Work / Gym / School).
  /// No-op if already present or cap reached.
  void addPresetLocation(String label) {
    if (state.locations.length >= OnboardingState.maxLocations) return;
    if (state.hasLocation(label)) return;
    final updated = [...state.locations, OnboardingLocation(label: label)];
    state = state.copyWith(locations: updated);
  }

  /// Adds a blank Custom location slot if cap not reached.
  void addCustomLocation() {
    if (state.locations.length >= OnboardingState.maxLocations) return;
    final updated = [
      ...state.locations,
      const OnboardingLocation(label: 'Custom'),
    ];
    state = state.copyWith(locations: updated);
  }

  /// Updates the customName of the Custom location at [index].
  void updateLocationName(int index, String name) {
    final list = [...state.locations];
    if (index < 0 || index >= list.length) return;
    list[index] = list[index].copyWith(customName: name);
    state = state.copyWith(locations: list);
  }

  /// Removes the location at [index].
  void removeLocation(int index) {
    final list = [...state.locations];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    state = state.copyWith(locations: list);
  }

  // Completion
  void completeOnboarding() =>
      state = state.copyWith(completed: true, currentStep: 5);

  void reset() => state = const OnboardingState();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
