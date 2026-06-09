/// Day 96-97 — Localization & Language Settings state.
///
/// Fully self-contained mock Riverpod state — no easy_localization package.
/// Covers 15-language catalogue, translation completeness, RTL flags,
/// live language switching, and a demo translation map.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Language model ───────────────────────────────────────────────────────────

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.flag,
    required this.isRTL,
    required this.completePct,
    required this.region,
  });

  final String code;         // BCP-47 e.g. 'en', 'hi', 'ar'
  final String englishName;
  final String nativeName;
  final String flag;         // emoji flag
  final bool   isRTL;
  final int    completePct;  // translation completeness 0-100
  final String region;       // e.g. 'Global', 'South Asia'

  bool get isComplete => completePct == 100;
  bool get isPartial  => completePct > 0 && completePct < 100;
  bool get isPending  => completePct == 0;
}

const kAppLanguages = <AppLanguage>[
  AppLanguage(
    code: 'en', englishName: 'English', nativeName: 'English',
    flag: '🇬🇧', isRTL: false, completePct: 100, region: 'Global',
  ),
  AppLanguage(
    code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी',
    flag: '🇮🇳', isRTL: false, completePct: 100, region: 'South Asia',
  ),
  AppLanguage(
    code: 'ta', englishName: 'Tamil', nativeName: 'தமிழ்',
    flag: '🇮🇳', isRTL: false, completePct: 87, region: 'South Asia',
  ),
  AppLanguage(
    code: 'te', englishName: 'Telugu', nativeName: 'తెలుగు',
    flag: '🇮🇳', isRTL: false, completePct: 82, region: 'South Asia',
  ),
  AppLanguage(
    code: 'ml', englishName: 'Malayalam', nativeName: 'മലയാളം',
    flag: '🇮🇳', isRTL: false, completePct: 74, region: 'South Asia',
  ),
  AppLanguage(
    code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা',
    flag: '🇧🇩', isRTL: false, completePct: 78, region: 'South Asia',
  ),
  AppLanguage(
    code: 'mr', englishName: 'Marathi', nativeName: 'मराठी',
    flag: '🇮🇳', isRTL: false, completePct: 69, region: 'South Asia',
  ),
  AppLanguage(
    code: 'gu', englishName: 'Gujarati', nativeName: 'ગુજરાતી',
    flag: '🇮🇳', isRTL: false, completePct: 61, region: 'South Asia',
  ),
  AppLanguage(
    code: 'pa', englishName: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ',
    flag: '🇮🇳', isRTL: false, completePct: 55, region: 'South Asia',
  ),
  AppLanguage(
    code: 'ur', englishName: 'Urdu', nativeName: 'اردو',
    flag: '🇵🇰', isRTL: true, completePct: 48, region: 'South Asia',
  ),
  AppLanguage(
    code: 'ar', englishName: 'Arabic', nativeName: 'العربية',
    flag: '🇸🇦', isRTL: true, completePct: 43, region: 'Middle East',
  ),
  AppLanguage(
    code: 'es', englishName: 'Spanish', nativeName: 'Español',
    flag: '🇪🇸', isRTL: false, completePct: 91, region: 'Latin America',
  ),
  AppLanguage(
    code: 'fr', englishName: 'French', nativeName: 'Français',
    flag: '🇫🇷', isRTL: false, completePct: 88, region: 'Europe',
  ),
  AppLanguage(
    code: 'pt', englishName: 'Portuguese', nativeName: 'Português',
    flag: '🇧🇷', isRTL: false, completePct: 76, region: 'Latin America',
  ),
  AppLanguage(
    code: 'de', englishName: 'German', nativeName: 'Deutsch',
    flag: '🇩🇪', isRTL: false, completePct: 83, region: 'Europe',
  ),
];

// ─── Demo translations ────────────────────────────────────────────────────────
// A small set of UI strings per language to power the live preview.

const kDemoTranslations = <String, Map<String, String>>{
  'en': {
    'trigger_sos':      'Trigger SOS',
    'im_safe':          "I'm Safe",
    'cancel':           'Cancel',
    'emergency_alert':  'Emergency Alert',
    'check_in':         'Check-in',
    'safe_zone':        'Safe Zone',
  },
  'hi': {
    'trigger_sos':      'SOS ट्रिगर करें',
    'im_safe':          'मैं सुरक्षित हूँ',
    'cancel':           'रद्द करें',
    'emergency_alert':  'आपातकालीन अलर्ट',
    'check_in':         'चेक-इन',
    'safe_zone':        'सुरक्षित क्षेत्र',
  },
  'ta': {
    'trigger_sos':      'SOS தூண்டு',
    'im_safe':          'நான் பாதுகாப்பாக இருக்கிறேன்',
    'cancel':           'ரத்து செய்',
    'emergency_alert':  'அவசர எச்சரிக்கை',
    'check_in':         'செக்-இன்',
    'safe_zone':        'பாதுகாப்பான மண்டலம்',
  },
  'te': {
    'trigger_sos':      'SOS ట్రిగర్',
    'im_safe':          'నేను సురక్షితంగా ఉన్నాను',
    'cancel':           'రద్దు',
    'emergency_alert':  'అత్యవసర హెచ్చరిక',
    'check_in':         'చెక్-ఇన్',
    'safe_zone':        'సురక్షిత మండలి',
  },
  'ml': {
    'trigger_sos':      'SOS ട്രിഗർ',
    'im_safe':          'ഞാൻ സുരക്ഷിതനാണ്',
    'cancel':           'റദ്ദാക്കുക',
    'emergency_alert':  'അടിയന്തര അലേർട്ട്',
    'check_in':         'ചെക്ക്-ഇൻ',
    'safe_zone':        'സുരക്ഷിത മേഖല',
  },
  'bn': {
    'trigger_sos':      'SOS চালু করুন',
    'im_safe':          'আমি নিরাপদ',
    'cancel':           'বাতিল',
    'emergency_alert':  'জরুরি সতর্কতা',
    'check_in':         'চেক-ইন',
    'safe_zone':        'নিরাপদ এলাকা',
  },
  'mr': {
    'trigger_sos':      'SOS सुरू करा',
    'im_safe':          'मी सुरक्षित आहे',
    'cancel':           'रद्द करा',
    'emergency_alert':  'आणीबाणी सतर्कता',
    'check_in':         'चेक-इन',
    'safe_zone':        'सुरक्षित क्षेत्र',
  },
  'gu': {
    'trigger_sos':      'SOS ટ્રિગર',
    'im_safe':          'હું સુરક્ષિત છું',
    'cancel':           'રદ કરો',
    'emergency_alert':  'કટોકટી ચેતવણી',
    'check_in':         'ચેક-ઇન',
    'safe_zone':        'સુરક્ષિત ઝોન',
  },
  'pa': {
    'trigger_sos':      'SOS ਚਾਲੂ ਕਰੋ',
    'im_safe':          'ਮੈਂ ਸੁਰੱਖਿਅਤ ਹਾਂ',
    'cancel':           'ਰੱਦ ਕਰੋ',
    'emergency_alert':  'ਐਮਰਜੈਂਸੀ ਚੇਤਾਵਨੀ',
    'check_in':         'ਚੈੱਕ-ਇਨ',
    'safe_zone':        'ਸੁਰੱਖਿਅਤ ਖੇਤਰ',
  },
  'ur': {
    'trigger_sos':      'SOS چالو کریں',
    'im_safe':          'میں محفوظ ہوں',
    'cancel':           'منسوخ',
    'emergency_alert':  'ہنگامی الرٹ',
    'check_in':         'چیک ان',
    'safe_zone':        'محفوظ علاقہ',
  },
  'ar': {
    'trigger_sos':      'تفعيل الإسعاف',
    'im_safe':          'أنا بأمان',
    'cancel':           'إلغاء',
    'emergency_alert':  'تنبيه طارئ',
    'check_in':         'تسجيل وصول',
    'safe_zone':        'منطقة آمنة',
  },
  'es': {
    'trigger_sos':      'Activar SOS',
    'im_safe':          'Estoy a salvo',
    'cancel':           'Cancelar',
    'emergency_alert':  'Alerta de emergencia',
    'check_in':         'Registro',
    'safe_zone':        'Zona segura',
  },
  'fr': {
    'trigger_sos':      'Déclencher SOS',
    'im_safe':          'Je suis en sécurité',
    'cancel':           'Annuler',
    'emergency_alert':  "Alerte d'urgence",
    'check_in':         'Enregistrement',
    'safe_zone':        'Zone sécurisée',
  },
  'pt': {
    'trigger_sos':      'Acionar SOS',
    'im_safe':          'Estou seguro',
    'cancel':           'Cancelar',
    'emergency_alert':  'Alerta de emergência',
    'check_in':         'Check-in',
    'safe_zone':        'Zona segura',
  },
  'de': {
    'trigger_sos':      'SOS auslösen',
    'im_safe':          'Ich bin sicher',
    'cancel':           'Abbrechen',
    'emergency_alert':  'Notfallwarnung',
    'check_in':         'Einchecken',
    'safe_zone':        'Sichere Zone',
  },
};

String demoTranslate(String code, String key) {
  return kDemoTranslations[code]?[key] ??
         kDemoTranslations['en']![key] ??
         key;
}

// ─── State ────────────────────────────────────────────────────────────────────

class LocalizationState {
  const LocalizationState({
    required this.appliedCode,
    required this.selectedCode,
    required this.isApplying,
    required this.searchQuery,
  });

  final String appliedCode;   // currently active in the app
  final String selectedCode;  // highlighted in the list (pending apply)
  final bool   isApplying;
  final String searchQuery;

  bool get hasPendingChange => appliedCode != selectedCode;

  LocalizationState copyWith({
    String? appliedCode,
    String? selectedCode,
    bool?   isApplying,
    String? searchQuery,
  }) {
    return LocalizationState(
      appliedCode:  appliedCode  ?? this.appliedCode,
      selectedCode: selectedCode ?? this.selectedCode,
      isApplying:   isApplying   ?? this.isApplying,
      searchQuery:  searchQuery  ?? this.searchQuery,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class LocalizationNotifier extends StateNotifier<LocalizationState> {
  LocalizationNotifier()
      : super(const LocalizationState(
          appliedCode:  'en',
          selectedCode: 'en',
          isApplying:   false,
          searchQuery:  '',
        ));

  void select(String code) {
    if (state.isApplying) {
      return;
    }
    state = state.copyWith(selectedCode: code);
  }

  Future<void> applyLanguage() async {
    if (!state.hasPendingChange || state.isApplying) {
      return;
    }
    state = state.copyWith(isApplying: true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    state = state.copyWith(
      appliedCode: state.selectedCode,
      isApplying:  false,
    );
  }

  void setSearch(String q) {
    state = state.copyWith(searchQuery: q.toLowerCase());
  }
}

final localizationProvider =
    StateNotifierProvider<LocalizationNotifier, LocalizationState>(
  (ref) => LocalizationNotifier(),
);

// ─── Derived providers ────────────────────────────────────────────────────────

final filteredLanguagesProvider = Provider<List<AppLanguage>>((ref) {
  final q = ref.watch(
      localizationProvider.select((s) => s.searchQuery));
  if (q.isEmpty) {
    return kAppLanguages;
  }
  return kAppLanguages.where((lang) {
    return lang.englishName.toLowerCase().contains(q) ||
           lang.nativeName.toLowerCase().contains(q) ||
           lang.code.toLowerCase().contains(q) ||
           lang.region.toLowerCase().contains(q);
  }).toList();
});

final appliedLanguageProvider = Provider<AppLanguage>((ref) {
  final code = ref.watch(
      localizationProvider.select((s) => s.appliedCode));
  return kAppLanguages.firstWhere(
    (l) => l.code == code,
    orElse: () => kAppLanguages.first,
  );
});

final selectedLanguageProvider = Provider<AppLanguage>((ref) {
  final code = ref.watch(
      localizationProvider.select((s) => s.selectedCode));
  return kAppLanguages.firstWhere(
    (l) => l.code == code,
    orElse: () => kAppLanguages.first,
  );
});

// Stats
class TranslationStats {
  const TranslationStats({
    required this.total,
    required this.complete,
    required this.partial,
    required this.pending,
  });
  final int total;
  final int complete;
  final int partial;
  final int pending;
}

final translationStatsProvider = Provider<TranslationStats>((ref) {
  var complete = 0;
  var partial  = 0;
  var pending  = 0;
  for (final l in kAppLanguages) {
    if (l.isComplete) {
      complete++;
    } else if (l.isPartial) {
      partial++;
    } else {
      pending++;
    }
  }
  return TranslationStats(
    total:    kAppLanguages.length,
    complete: complete,
    partial:  partial,
    pending:  pending,
  );
});
