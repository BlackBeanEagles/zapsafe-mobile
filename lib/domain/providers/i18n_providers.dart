/// Days 101-102 — i18n / Localization state.
///
/// Owns the [I18nState] notifier (active locale, RTL flag) used by both
/// Day101I18nSetupScreen and Day102TranslationDemoScreen.
/// All 15 supported languages are defined here as [LangInfo] constants.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class LangInfo {
  const LangInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.rtl = false,
  });

  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool rtl;

  Locale get locale => Locale(code);
}

// Day 341 — 18 supported languages (15 original + sw/id/th, Section J
// languages 16-18). Order: Indian first, then international, then Section J
// additions in spec order. See day341_languages_16_18_screen.dart.
const List<LangInfo> kSupportedLanguages = [
  LangInfo(code: 'en', name: 'English',    nativeName: 'English',    flag: '🇬🇧'),
  LangInfo(code: 'hi', name: 'Hindi',      nativeName: 'हिन्दी',      flag: '🇮🇳'),
  LangInfo(code: 'ta', name: 'Tamil',      nativeName: 'தமிழ்',       flag: '🇮🇳'),
  LangInfo(code: 'te', name: 'Telugu',     nativeName: 'తెలుగు',      flag: '🇮🇳'),
  LangInfo(code: 'ml', name: 'Malayalam',  nativeName: 'മലയാളം',     flag: '🇮🇳'),
  LangInfo(code: 'bn', name: 'Bengali',    nativeName: 'বাংলা',       flag: '🇮🇳'),
  LangInfo(code: 'mr', name: 'Marathi',    nativeName: 'मराठी',       flag: '🇮🇳'),
  LangInfo(code: 'gu', name: 'Gujarati',   nativeName: 'ગુજરાતી',    flag: '🇮🇳'),
  LangInfo(code: 'pa', name: 'Punjabi',    nativeName: 'ਪੰਜਾਬੀ',     flag: '🇮🇳'),
  LangInfo(code: 'ur', name: 'Urdu',       nativeName: 'اردو',        flag: '🇵🇰', rtl: true),
  LangInfo(code: 'ar', name: 'Arabic',     nativeName: 'العربية',     flag: '🇸🇦', rtl: true),
  LangInfo(code: 'es', name: 'Spanish',    nativeName: 'Español',     flag: '🇪🇸'),
  LangInfo(code: 'fr', name: 'French',     nativeName: 'Français',    flag: '🇫🇷'),
  LangInfo(code: 'pt', name: 'Portuguese', nativeName: 'Português',   flag: '🇧🇷'),
  LangInfo(code: 'de', name: 'German',     nativeName: 'Deutsch',     flag: '🇩🇪'),
  LangInfo(code: 'sw', name: 'Swahili',    nativeName: 'Kiswahili',   flag: '🇰🇪'),
  LangInfo(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flag: '🇮🇩'),
  LangInfo(code: 'th', name: 'Thai',       nativeName: 'ไทย',         flag: '🇹🇭'),
];

// Demo translations shown on Day102TranslationDemoScreen (subset of key strings)
// Keyed by locale code → map of key → translated value.
const Map<String, Map<String, String>> kDemoTranslations = {
  'en': {
    'tagline':     'Safety in your hands',
    'sos.trigger': 'TRIGGER SOS',
    'sos.active':  'SOS ACTIVE',
    'home.status': 'You are safe',
    'common.save': 'Save',
    'common.done': 'Done',
    'settings':    'Settings',
    'premium':     'Upgrade to Premium',
  },
  'hi': {
    'tagline':     'आपकी सुरक्षा आपके हाथों में',
    'sos.trigger': 'SOS चालू करें',
    'sos.active':  'SOS सक्रिय',
    'home.status': 'आप सुरक्षित हैं',
    'common.save': 'सहेजें',
    'common.done': 'हो गया',
    'settings':    'सेटिंग्स',
    'premium':     'प्रीमियम में अपग्रेड करें',
  },
  'ta': {
    'tagline':     'உங்கள் பாதுகாப்பு உங்கள் கைகளில்',
    'sos.trigger': 'SOS தொடங்கு',
    'sos.active':  'SOS செயல்பாட்டில் உள்ளது',
    'home.status': 'நீங்கள் பாதுகாப்பாக உள்ளீர்கள்',
    'common.save': 'சேமி',
    'common.done': 'முடிந்தது',
    'settings':    'அமைப்புகள்',
    'premium':     'Premium க்கு மேம்படுத்து',
  },
  'te': {
    'tagline':     'మీ భద్రత మీ చేతుల్లో',
    'sos.trigger': 'SOS ప్రారంభించు',
    'sos.active':  'SOS సక్రియంగా ఉంది',
    'home.status': 'మీరు సురక్షితంగా ఉన్నారు',
    'common.save': 'సేవ్ చేయి',
    'common.done': 'పూర్తైంది',
    'settings':    'సెట్టింగ్స్',
    'premium':     'Premiumకి అప్‌గ్రేడ్ చేయి',
  },
  'ml': {
    'tagline':     'നിങ്ങളുടെ സുരക്ഷ നിങ്ങളുടെ കൈകളിൽ',
    'sos.trigger': 'SOS ആരംഭിക്കുക',
    'sos.active':  'SOS സക്രിയം',
    'home.status': 'നിങ്ങൾ സുരക്ഷിതരാണ്',
    'common.save': 'സേവ് ചെയ്യുക',
    'common.done': 'പൂർത്തിയായി',
    'settings':    'ക്രമീകരണങ്ങൾ',
    'premium':     'Premium ലേക്ക് അപ്‌ഗ്രേഡ് ചെയ്യുക',
  },
  'bn': {
    'tagline':     'আপনার নিরাপত্তা আপনার হাতে',
    'sos.trigger': 'SOS চালু করুন',
    'sos.active':  'SOS সক্রিয়',
    'home.status': 'আপনি নিরাপদ',
    'common.save': 'সেভ করুন',
    'common.done': 'হয়েছে',
    'settings':    'সেটিংস',
    'premium':     'Premium এ আপগ্রেড করুন',
  },
  'mr': {
    'tagline':     'तुमची सुरक्षा तुमच्या हातात',
    'sos.trigger': 'SOS सुरू करा',
    'sos.active':  'SOS सक्रिय',
    'home.status': 'तुम्ही सुरक्षित आहात',
    'common.save': 'सेव्ह करा',
    'common.done': 'झाले',
    'settings':    'सेटिंग्ज',
    'premium':     'Premium वर अपग्रेड करा',
  },
  'gu': {
    'tagline':     'તમારી સુરક્ષા તમારા હાથમાં',
    'sos.trigger': 'SOS શરૂ કરો',
    'sos.active':  'SOS સક્રિય',
    'home.status': 'તમે સુરક્ષિત છો',
    'common.save': 'સાચવો',
    'common.done': 'થઈ ગયું',
    'settings':    'સેટિંગ્સ',
    'premium':     'Premium પર અપગ્રેડ કરો',
  },
  'pa': {
    'tagline':     'ਤੁਹਾਡੀ ਸੁਰੱਖਿਆ ਤੁਹਾਡੇ ਹੱਥਾਂ ਵਿੱਚ',
    'sos.trigger': 'SOS ਸ਼ੁਰੂ ਕਰੋ',
    'sos.active':  'SOS ਸਰਗਰਮ',
    'home.status': 'ਤੁਸੀਂ ਸੁਰੱਖਿਅਤ ਹੋ',
    'common.save': 'ਸੇਵ ਕਰੋ',
    'common.done': 'ਹੋ ਗਿਆ',
    'settings':    'ਸੈਟਿੰਗਾਂ',
    'premium':     'Premium ਵਿੱਚ ਅਪਗ੍ਰੇਡ ਕਰੋ',
  },
  'ur': {
    'tagline':     'آپ کی حفاظت آپ کے ہاتھوں میں',
    'sos.trigger': 'SOS شروع کریں',
    'sos.active':  'SOS فعال',
    'home.status': 'آپ محفوظ ہیں',
    'common.save': 'محفوظ کریں',
    'common.done': 'مکمل',
    'settings':    'ترتیبات',
    'premium':     'Premium میں اپگریڈ کریں',
  },
  'ar': {
    'tagline':     'سلامتك في يديك',
    'sos.trigger': 'تفعيل SOS',
    'sos.active':  'SOS نشط',
    'home.status': 'أنت بأمان',
    'common.save': 'حفظ',
    'common.done': 'تم',
    'settings':    'الإعدادات',
    'premium':     'الترقية إلى Premium',
  },
  'es': {
    'tagline':     'Tu seguridad en tus manos',
    'sos.trigger': 'ACTIVAR SOS',
    'sos.active':  'SOS ACTIVO',
    'home.status': 'Estás seguro/a',
    'common.save': 'Guardar',
    'common.done': 'Listo',
    'settings':    'Configuración',
    'premium':     'Actualizar a Premium',
  },
  'fr': {
    'tagline':     'Votre sécurité entre vos mains',
    'sos.trigger': 'DÉCLENCHER SOS',
    'sos.active':  'SOS ACTIF',
    'home.status': 'Vous êtes en sécurité',
    'common.save': 'Enregistrer',
    'common.done': 'Terminé',
    'settings':    'Paramètres',
    'premium':     'Passer à Premium',
  },
  'pt': {
    'tagline':     'Sua segurança em suas mãos',
    'sos.trigger': 'ACIONAR SOS',
    'sos.active':  'SOS ATIVO',
    'home.status': 'Você está seguro/a',
    'common.save': 'Salvar',
    'common.done': 'Concluído',
    'settings':    'Configurações',
    'premium':     'Atualizar para Premium',
  },
  'de': {
    'tagline':     'Ihre Sicherheit in Ihren Händen',
    'sos.trigger': 'SOS AUSLÖSEN',
    'sos.active':  'SOS AKTIV',
    'home.status': 'Sie sind sicher',
    'common.save': 'Speichern',
    'common.done': 'Fertig',
    'settings':    'Einstellungen',
    'premium':     'Auf Premium upgraden',
  },
};

// Day 104 — full onboarding step translations for all 15 locales.
// Each entry: [title, description] for steps 1-5.
const Map<String, List<List<String>>> kOnboardingSteps = {
  'en': [
    ['Welcome to ZapSafe',   'Your personal safety companion — always watching, always ready'],
    ['Emergency Contacts',   'Add the people who look out for you — family, friends, colleagues'],
    ['Location & Audio',     'Real-time threat detection needs your location and microphone'],
    ['Customise Alerts',     'Set the sensitivity thresholds that work best for your lifestyle'],
    ["You're all set!",      'ZapSafe is armed and ready to protect you. Stay safe.'],
  ],
  'hi': [
    ['ZapSafe में आपका स्वागत है',  'आपका व्यक्तिगत सुरक्षा साथी — हमेशा सतर्क, हमेशा तैयार'],
    ['आपातकालीन संपर्क',            'उन लोगों को जोड़ें जो आपकी परवाह करते हैं — परिवार, दोस्त, सहकर्मी'],
    ['स्थान और ऑडियो',              'वास्तविक समय में खतरे की पहचान के लिए स्थान और माइक्रोफोन चाहिए'],
    ['अलर्ट अनुकूलित करें',         'अपनी जीवनशैली के अनुसार संवेदनशीलता सीमाएं निर्धारित करें'],
    ['सब तैयार है!',                'ZapSafe आपकी सुरक्षा के लिए तैयार है। सुरक्षित रहें।'],
  ],
  'ta': [
    ['ZapSafe-க்கு வரவேற்கிறோம்',  'உங்கள் தனிப்பட்ட பாதுகாப்பு துணை — எப்போதும் கண்காணிக்கிறது'],
    ['அவசர தொடர்புகள்',             'உங்களை கவனிக்கும் நபர்களை சேர்க்கவும் — குடும்பம், நண்பர்கள்'],
    ['இருப்பிடம் & ஆடியோ',          'நிகழ்நேர அச்சுறுத்தல் கண்டறிதலுக்கு இருப்பிடம் தேவை'],
    ['விழிப்பூட்டல்கள் தனிப்பயனாக்கு', 'உங்கள் வாழ்க்கை முறைக்கு ஏற்ற வரம்புகளை அமைக்கவும்'],
    ['அனைத்தும் தயார்!',             'ZapSafe உங்களை பாதுகாக்க தயாராக உள்ளது. பாதுகாப்பாக இருங்கள்.'],
  ],
  'te': [
    ['ZapSafe కు స్వాగతం',          'మీ వ్యక్తిగత భద్రత సహాయకుడు — ఎల్లప్పుడూ జాగ్రత్తగా ఉంటుంది'],
    ['అత్యవసర పరిచయాలు',            'మీకు సహాయం చేసే వ్యక్తులను జోడించండి — కుటుంబం, స్నేహితులు'],
    ['స్థానం & ఆడియో',              'నిజ సమయ ముప్పు గుర్తింపుకు మీ స్థానం అవసరం'],
    ['హెచ్చరికలు అనుకూలీకరించు',    'మీ జీవనశైలికి అనుగుణంగా సెన్సిటివిటీ సెట్ చేయండి'],
    ['మీరు సిద్ధంగా ఉన్నారు!',       'ZapSafe మీ రక్షణకు సిద్ధంగా ఉంది. సురక్షితంగా ఉండండి.'],
  ],
  'ml': [
    ['ZapSafe-ലേക്ക് സ്വാഗതം',     'നിങ്ങളുടെ വ്യക്തിഗത സുരക്ഷ സഹായി — എപ്പോഴും ജാഗ്രത'],
    ['അടിയന്തര ബന്ധങ്ങൾ',           'നിങ്ങളെ ശ്രദ്ധിക്കുന്ന ആളുകളെ ചേർക്കുക — കുടുംബം, സ്നേഹിതർ'],
    ['സ്ഥാനം & ഓഡിയോ',             'തത്സമയ ഭീഷണി കണ്ടെത്തലിന് നിങ്ങളുടെ സ്ഥാനം ആവശ്യം'],
    ['അലേർട്ടുകൾ ഇഷ്ടാനുസൃതമാക്കുക','നിങ്ങളുടെ ജീവിതശൈലിക്ക് അനുയോജ്യമായ സെൻസിറ്റിവിറ്റി'],
    ['എല്ലാം തയ്യാറായി!',           'ZapSafe നിങ്ങളെ സംരക്ഷിക്കാൻ തയ്യാറാണ്. സുരക്ഷിതരായിരിക്കൂ.'],
  ],
  'bn': [
    ['ZapSafe-এ স্বাগতম',           'আপনার ব্যক্তিগত নিরাপত্তা সহায়ক — সবসময় সতর্ক, সবসময় প্রস্তুত'],
    ['জরুরী পরিচিতি',               'যারা আপনার যত্ন নেন তাদের যোগ করুন — পরিবার, বন্ধু'],
    ['অবস্থান ও অডিও',              'রিয়েল-টাইম হুমকি সনাক্তকরণে আপনার অবস্থান প্রয়োজন'],
    ['সতর্কতা কাস্টমাইজ করুন',     'আপনার জীবনধারা অনুযায়ী সংবেদনশীলতা সেট করুন'],
    ['সব প্রস্তুত!',                'ZapSafe আপনাকে রক্ষা করতে প্রস্তুত। নিরাপদ থাকুন।'],
  ],
  'mr': [
    ['ZapSafe मध्ये आपले स्वागत आहे','आपला वैयक्तिक सुरक्षा सहाय्यक — सदैव सजग, सदैव तयार'],
    ['आणीबाणी संपर्क',              'आपली काळजी घेणाऱ्या लोकांना जोडा — कुटुंब, मित्र'],
    ['स्थान आणि ऑडिओ',             'रिअल-टाइम धोका ओळखण्यासाठी आपले स्थान आवश्यक'],
    ['सूचना सानुकूलित करा',         'आपल्या जीवनशैलीनुसार संवेदनशीलता सेट करा'],
    ['सर्व तयार!',                  'ZapSafe आपले संरक्षण करण्यास तयार आहे. सुरक्षित राहा.'],
  ],
  'gu': [
    ['ZapSafe માં આપका स्वागत है', 'તમારો વ્યક્તિગત સુરક્ષા સહાયક — હંમેશા સજ્જ, હંમેશા તૈyar'],
    ['કટોકટીના સંપર્કો',            'જે લોકો તમારી કાળજી લે છે તેમને ઉمेरો — પ़ریवार, مित्र'],
    ['સ્થान अने ऑडिओ',             'রিয়েল-ટাइム ख़तरा शोধ माटे तमारুं स्थान जरूरी'],
    ['ছেتवणी कस्टमाइज করো',        'तमारी जीवनशैली अनुसार संवेदनशीलता सेट করो'],
    ['বদ्दলुं तैयार!',              'ZapSafe तमारी सुरक्षा माटे तैyar छे. सुरक्षित রहো.'],
  ],
  'pa': [
    ['ZapSafe ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ','ਤੁਹਾਡਾ ਨਿੱਜੀ ਸੁਰੱਖਿਆ ਸਾਥੀ — ਹਮੇਸ਼ਾ ਸਤਰਕ, ਹਮੇਸ਼ਾ ਤਿਆਰ'],
    ['ਐਮਰਜੈਂਸੀ ਸੰਪਰਕ',             'ਉਨ੍ਹਾਂ ਲੋਕਾਂ ਨੂੰ ਜੋੜੋ ਜੋ ਤੁਹਾਡੀ ਪਰਵਾਹ ਕਰਦੇ ਹਨ'],
    ['ਸਥਾਨ ਅਤੇ ਆਡੀਓ',             'ਅਸਲ-ਸਮੇਂ ਦੀ ਖ਼ਤਰੇ ਦੀ ਜਾਂਚ ਲਈ ਤੁਹਾਡਾ ਸਥਾਨ ਜ਼ਰੂਰੀ ਹੈ'],
    ['ਅਲਰਟ ਕਸਟਮਾਈਜ਼ ਕਰੋ',          'ਆਪਣੀ ਜੀਵਨਸ਼ੈਲੀ ਲਈ ਸੰਵੇਦਨਸ਼ੀਲਤਾ ਸੈੱਟ ਕਰੋ'],
    ['ਸਭ ਤਿਆਰ!',                   'ZapSafe ਤੁਹਾਡੀ ਸੁਰੱਖਿਆ ਲਈ ਤਿਆਰ ਹੈ। ਸੁਰੱਖਿਅਤ ਰਹੋ।'],
  ],
  'ur': [
    ['ZapSafe میں خوش آمدید',       'آپ کا ذاتی حفاظتی ساتھی — ہمیشہ چوکنا، ہمیشہ تیار'],
    ['ہنگامی رابطے',                'ان لوگوں کو شامل کریں جو آپ کی پرواہ کرتے ہیں'],
    ['مقام اور آڈیو',               'حقیقی وقت خطرے کی شناخت کے لیے آپ کا مقام درکار ہے'],
    ['الرٹس کو اپنی مرضی کے مطابق بنائیں','اپنے طرز زندگی کے لیے حساسیت مقرر کریں'],
    ['سب کچھ تیار!',               'ZapSafe آپ کی حفاظت کے لیے تیار ہے۔ محفوظ رہیں۔'],
  ],
  'ar': [
    ['مرحباً بك في ZapSafe',         'رفيقك الشخصي للسلامة — يراقب دائماً، جاهز دائماً'],
    ['جهات الاتصال للطوارئ',         'أضف الأشخاص الذين يهتمون بك — عائلتك، أصدقاؤك'],
    ['الموقع والصوت',               'يحتاج الكشف عن التهديدات إلى موقعك والميكروفون'],
    ['تخصيص التنبيهات',             'اضبط عتبات الحساسية التي تناسب نمط حياتك'],
    ['أنت جاهز!',                   'ZapSafe مسلح ومستعد لحمايتك. ابقَ بأمان.'],
  ],
  'es': [
    ['Bienvenido a ZapSafe',         'Tu compañero de seguridad personal — siempre vigilante, siempre listo'],
    ['Contactos de emergencia',      'Agrega a las personas que velan por ti — familia, amigos'],
    ['Ubicación y audio',            'La detección de amenazas en tiempo real necesita tu ubicación'],
    ['Personalizar alertas',         'Establece los umbrales de sensibilidad que mejor se adapten'],
    ['¡Todo listo!',                 'ZapSafe está armado y listo para protegerte. Mantente seguro.'],
  ],
  'fr': [
    ['Bienvenue sur ZapSafe',        'Votre compagnon de sécurité personnel — toujours vigilant, toujours prêt'],
    ["Contacts d'urgence",           'Ajoutez les personnes qui veillent sur vous — famille, amis'],
    ['Localisation et audio',        'La détection de menaces en temps réel nécessite votre position'],
    ['Personnaliser les alertes',    'Définissez les seuils de sensibilité adaptés à votre mode de vie'],
    ['Tout est prêt!',               'ZapSafe est armé et prêt à vous protéger. Restez en sécurité.'],
  ],
  'pt': [
    ['Bem-vindo ao ZapSafe',         'Seu companheiro pessoal de segurança — sempre vigilante, sempre pronto'],
    ['Contatos de emergência',       'Adicione as pessoas que cuidam de você — família, amigos'],
    ['Localização e áudio',          'A detecção de ameaças em tempo real precisa da sua localização'],
    ['Personalizar alertas',         'Defina os limites de sensibilidade que funcionam melhor para você'],
    ['Tudo pronto!',                 'ZapSafe está armado e pronto para protegê-lo. Fique seguro.'],
  ],
  'de': [
    ['Willkommen bei ZapSafe',       'Ihr persönlicher Sicherheitsbegleiter — immer wachsam, immer bereit'],
    ['Notfallkontakte',              'Fügen Sie die Personen hinzu, die auf Sie achten — Familie, Freunde'],
    ['Standort & Audio',             'Echtzeit-Bedrohungserkennung benötigt Ihren Standort und das Mikrofon'],
    ['Benachrichtigungen anpassen',  'Stellen Sie die Empfindlichkeitsschwellen ein, die am besten zu Ihnen passen'],
    ['Alles bereit!',                'ZapSafe ist bereit, Sie zu schützen. Bleiben Sie sicher.'],
  ],
};

// Day 107 — SOS alert lifecycle labels (4 stages) + alerts/vault/profile preview.
// Each list: [triggered, sending, escalating, resolved]
const Map<String, List<String>> kAlertLifecycle = {
  'en': ['SOS Triggered', 'Sending to contacts…', 'Escalating to tier 2…', 'Alert Resolved ✓'],
  'hi': ['SOS चालू हुआ', 'संपर्कों को भेजा जा रहा है…', 'श्रेणी 2 को बढ़ाया जा रहा है…', 'अलर्ट हल हुआ ✓'],
  'ta': ['SOS தொடங்கியது', 'தொடர்புகளுக்கு அனுப்புகிறது…', 'நிலை 2க்கு அதிகரிக்கிறது…', 'விழிப்பூட்டல் தீர்க்கப்பட்டது ✓'],
  'te': ['SOS ప్రారంభమైంది', 'పరిచయాలకు పంపుతోంది…', 'టియర్ 2కు పెంచుతోంది…', 'హెచ్చరిక పరిష్కారమైంది ✓'],
  'ml': ['SOS ആരംഭിച്ചു', 'ബന്ധങ്ങൾക്ക് അയക്കുന്നു…', 'ടയർ 2ലേക്ക് ഉയർത്തുന്നു…', 'അലേർട്ട് പരിഹരിച്ചു ✓'],
  'bn': ['SOS চালু হয়েছে', 'পরিচিতিদের পাঠানো হচ্ছে…', 'টায়ার 2 এ বাড়ানো হচ্ছে…', 'সতর্কতা সমাধান হয়েছে ✓'],
  'mr': ['SOS सुरू झाला', 'संपर्कांना पाठवत आहे…', 'स्तर 2 कडे वाढवत आहे…', 'अलर्ट सोडवला ✓'],
  'gu': ['SOS શરૂ થયો', 'સંપર્કોને મોકલી રહ્યો છે…', 'સ્તર 2 સુધી વધારી રહ્યો છે…', 'ચેતવણી ઉકેલાઈ ✓'],
  'pa': ['SOS ਸ਼ੁਰੂ ਹੋਇਆ', 'ਸੰਪਰਕਾਂ ਨੂੰ ਭੇਜਿਆ ਜਾ ਰਿਹਾ ਹੈ…', 'ਟੀਅਰ 2 ਤੱਕ ਵਧਾਇਆ ਜਾ ਰਿਹਾ ਹੈ…', 'ਅਲਰਟ ਹੱਲ ਹੋਇਆ ✓'],
  'ur': ['SOS شروع ہوا', 'رابطوں کو بھیجا جا رہا ہے…', 'ٹائر 2 تک بڑھایا جا رہا ہے…', 'الرٹ حل ہوا ✓'],
  'ar': ['تم تفعيل SOS', 'جاري الإرسال للجهات…', 'التصعيد إلى المستوى 2…', 'تم حل التنبيه ✓'],
  'es': ['SOS activado', 'Enviando a contactos…', 'Escalando al nivel 2…', 'Alerta resuelta ✓'],
  'fr': ['SOS déclenché', 'Envoi aux contacts…', 'Escalade vers le niveau 2…', 'Alerte résolue ✓'],
  'pt': ['SOS acionado', 'Enviando para contatos…', 'Escalando para nível 2…', 'Alerta resolvido ✓'],
  'de': ['SOS ausgelöst', 'Wird an Kontakte gesendet…', 'Eskalation auf Stufe 2…', 'Alarm behoben ✓'],
};

// alerts + vault + profile 4-key preview per language
const Map<String, Map<String, String>> kMonth4Translations = {
  'en': {'alerts.pending': 'Alert Pending', 'vault.title': 'Evidence Vault', 'profile.verified': 'Verified', 'alerts.view_location': 'View Location'},
  'hi': {'alerts.pending': 'अलर्ट लंबित', 'vault.title': 'साक्ष्य तिजोरी', 'profile.verified': 'सत्यापित', 'alerts.view_location': 'स्थान देखें'},
  'ta': {'alerts.pending': 'விழிப்பூட்டல் நிலுவையில்', 'vault.title': 'சான்று பெட்டகம்', 'profile.verified': 'சரிபார்க்கப்பட்டது', 'alerts.view_location': 'இருப்பிடம் காண்க'},
  'te': {'alerts.pending': 'హెచ్చరిక పెండింగ్', 'vault.title': 'సాక్ష్యం వాల్ట్', 'profile.verified': 'ధృవీకరించబడింది', 'alerts.view_location': 'స్థానం చూడండి'},
  'ml': {'alerts.pending': 'അലേർട്ട് തീർപ്പാകാത്തത്', 'vault.title': 'തെളിവ് വോൾട്ട്', 'profile.verified': 'സ്ഥിരീകരിച്ചു', 'alerts.view_location': 'സ്ഥാനം കാണുക'},
  'bn': {'alerts.pending': 'সতর্কতা মুলতুবি', 'vault.title': 'প্রমাণ ভল্ট', 'profile.verified': 'যাচাইকৃত', 'alerts.view_location': 'অবস্থান দেখুন'},
  'mr': {'alerts.pending': 'अलर्ट प्रलंबित', 'vault.title': 'पुरावा तिजोरी', 'profile.verified': 'सत्यापित', 'alerts.view_location': 'स्थान पहा'},
  'gu': {'alerts.pending': 'ચેतवणी બाकी', 'vault.title': 'પুরावा तિजોरી', 'profile.verified': 'ચकासाyelena', 'alerts.view_location': 'સ્થान જুઓ'},
  'pa': {'alerts.pending': 'ਅਲਰਟ ਲੰਬਿਤ', 'vault.title': 'ਸਬੂਤ ਤਿਜੋਰੀ', 'profile.verified': 'ਤਸਦੀਕ ਹੋਇਆ', 'alerts.view_location': 'ਸਥਾਨ ਦੇਖੋ'},
  'ur': {'alerts.pending': 'الرٹ زیر التواء', 'vault.title': 'ثبوت والٹ', 'profile.verified': 'تصدیق شدہ', 'alerts.view_location': 'مقام دیکھیں'},
  'ar': {'alerts.pending': 'تنبيه معلق', 'vault.title': 'خزنة الأدلة', 'profile.verified': 'موثق', 'alerts.view_location': 'عرض الموقع'},
  'es': {'alerts.pending': 'Alerta pendiente', 'vault.title': 'Bóveda de evidencia', 'profile.verified': 'Verificado', 'alerts.view_location': 'Ver ubicación'},
  'fr': {'alerts.pending': 'Alerte en attente', 'vault.title': "Coffre à preuves", 'profile.verified': 'Vérifié', 'alerts.view_location': 'Voir la position'},
  'pt': {'alerts.pending': 'Alerta pendente', 'vault.title': 'Cofre de evidências', 'profile.verified': 'Verificado', 'alerts.view_location': 'Ver localização'},
  'de': {'alerts.pending': 'Alarm ausstehend', 'vault.title': 'Beweismittel-Tresor', 'profile.verified': 'Verifiziert', 'alerts.view_location': 'Standort anzeigen'},
};

// Day 106 — Detection flow state labels + zones/checkin/incidents preview keys.
// Each state list: [idle, listening, analyzing, alert, sos_sent]
const Map<String, List<String>> kDetectionStates = {
  'en': ['Idle — Monitoring', 'Listening for sounds…', 'Analysing audio…', 'Threat Detected!', 'SOS Sent ✓'],
  'hi': ['निष्क्रिय — निगरानी', 'ध्वनि सुन रहा है…', 'ऑडियो विश्लेषण…', 'खतरा पहचाना!', 'SOS भेजा गया ✓'],
  'ta': ['செயலற்று — கண்காணிக்கிறது', 'ஒலியை கேட்கிறது…', 'ஆடியோ பகுப்பாய்வு…', 'அச்சுறுத்தல் கண்டறியப்பட்டது!', 'SOS அனுப்பப்பட்டது ✓'],
  'te': ['నిష్క్రియ — పర్యవేక్షణ', 'శబ్దాలు వింటోంది…', 'ఆడియో విశ్లేషణ…', 'ముప్పు గుర్తించబడింది!', 'SOS పంపబడింది ✓'],
  'ml': ['നിష്‌ക്രിയ — നിരീക്ഷണം', 'ശബ്ദം ശ്രവിക്കുന്നു…', 'ഓഡിയോ വിശകലനം…', 'ഭീഷണി കണ്ടെത്തി!', 'SOS അയച്ചു ✓'],
  'bn': ['নিষ্ক্রিয় — পর্যবেক্ষণ', 'শব্দ শুনছে…', 'অডিও বিশ্লেষণ…', 'হুমকি সনাক্ত!', 'SOS পাঠানো হয়েছে ✓'],
  'mr': ['निष्क्रिय — निरीक्षण', 'आवाज ऐकत आहे…', 'ऑडिओ विश्लेषण…', 'धोका आढळला!', 'SOS पाठवले ✓'],
  'gu': ['નિષ્ક્રિય — નિગ્રાની', 'અવાજ સાંભળે છે…', 'ઑડિઓ વિશ્લેષણ…', 'ખતરો શોધ્યો!', 'SOS મોકલ્યો ✓'],
  'pa': ['ਅਕਿਰਿਆਸ਼ੀਲ — ਨਿਗਰਾਨੀ', 'ਆਵਾਜ਼ ਸੁਣ ਰਿਹਾ ਹੈ…', 'ਆਡੀਓ ਵਿਸ਼ਲੇਸ਼ਣ…', 'ਖ਼ਤਰਾ ਮਿਲਿਆ!', 'SOS ਭੇਜਿਆ ✓'],
  'ur': ['غیر فعال — نگرانی', 'آواز سن رہا ہے…', 'آڈیو تجزیہ…', 'خطرہ محسوس ہوا!', 'SOS بھیج دیا ✓'],
  'ar': ['خامل — مراقبة', 'يستمع للأصوات…', 'تحليل الصوت…', 'تهديد محتمل!', 'تم إرسال SOS ✓'],
  'es': ['En espera — Monitoreando', 'Escuchando sonidos…', 'Analizando audio…', '¡Amenaza detectada!', 'SOS enviado ✓'],
  'fr': ['En attente — Surveillance', 'Écoute des sons…', "Analyse de l'audio…", 'Menace détectée!', 'SOS envoyé ✓'],
  'pt': ['Inativo — Monitorando', 'Ouvindo sons…', 'Analisando áudio…', 'Ameaça detectada!', 'SOS enviado ✓'],
  'de': ['Inaktiv — Überwachung', 'Hört auf Geräusche…', 'Audio wird analysiert…', 'Bedrohung erkannt!', 'SOS gesendet ✓'],
};

// zones + checkin + incidents preview (4 key subset per language)
const Map<String, Map<String, String>> kZoneCheckinTranslations = {
  'en': {'zones.title': 'Safe Zones', 'zones.home': 'Home', 'checkin.confirm_safe': "Confirm I'm Safe", 'incidents.high': 'High Severity'},
  'hi': {'zones.title': 'सुरक्षित क्षेत्र', 'zones.home': 'घर', 'checkin.confirm_safe': 'पुष्टि करें कि मैं सुरक्षित हूं', 'incidents.high': 'उच्च गंभीरता'},
  'ta': {'zones.title': 'பாதுகாப்பான மண்டலங்கள்', 'zones.home': 'வீடு', 'checkin.confirm_safe': 'நான் பாதுகாப்பாக இருக்கிறேன்', 'incidents.high': 'அதிக தீவிரம்'},
  'te': {'zones.title': 'సురక్షిత జోన్లు', 'zones.home': 'ఇల్లు', 'checkin.confirm_safe': 'నేను సురక్షితంగా ఉన్నాను', 'incidents.high': 'అధిక తీవ్రత'},
  'ml': {'zones.title': 'സുരക്ഷിത മേഖലകൾ', 'zones.home': 'വീട്', 'checkin.confirm_safe': 'ഞാൻ സുരക്ഷിതനാണ്', 'incidents.high': 'ഉയർന്ന തീവ്രത'},
  'bn': {'zones.title': 'নিরাপদ অঞ্চল', 'zones.home': 'বাড়ি', 'checkin.confirm_safe': 'আমি নিরাপদ আছি', 'incidents.high': 'উচ্চ মাত্রা'},
  'mr': {'zones.title': 'सुरक्षित क्षेत्रे', 'zones.home': 'घर', 'checkin.confirm_safe': 'मी सुरक्षित आहे', 'incidents.high': 'उच्च तीव्रता'},
  'gu': {'zones.title': 'સુરક્ષિત ઝોન', 'zones.home': 'ઘર', 'checkin.confirm_safe': 'હું સુરક્ષિત છું', 'incidents.high': 'ઉચ્ચ ગંભીરતા'},
  'pa': {'zones.title': 'ਸੁਰੱਖਿਅਤ ਜ਼ੋਨ', 'zones.home': 'ਘਰ', 'checkin.confirm_safe': 'ਮੈਂ ਸੁਰੱਖਿਅਤ ਹਾਂ', 'incidents.high': 'ਉੱਚ ਗੰਭੀਰਤਾ'},
  'ur': {'zones.title': 'محفوظ علاقے', 'zones.home': 'گھر', 'checkin.confirm_safe': 'میں محفوظ ہوں', 'incidents.high': 'اعلیٰ شدت'},
  'ar': {'zones.title': 'المناطق الآمنة', 'zones.home': 'المنزل', 'checkin.confirm_safe': 'تأكيد أنني بأمان', 'incidents.high': 'خطورة عالية'},
  'es': {'zones.title': 'Zonas Seguras', 'zones.home': 'Casa', 'checkin.confirm_safe': 'Confirmar que estoy seguro/a', 'incidents.high': 'Alta gravedad'},
  'fr': {'zones.title': 'Zones sûres', 'zones.home': 'Domicile', 'checkin.confirm_safe': 'Confirmer que je suis en sécurité', 'incidents.high': 'Haute gravité'},
  'pt': {'zones.title': 'Zonas Seguras', 'zones.home': 'Casa', 'checkin.confirm_safe': 'Confirmar que estou seguro/a', 'incidents.high': 'Alta gravidade'},
  'de': {'zones.title': 'Sichere Zonen', 'zones.home': 'Zuhause', 'checkin.confirm_safe': 'Bestätigen, dass ich sicher bin', 'incidents.high': 'Hoher Schweregrad'},
};

// Day 105 — Month 3 sample translations: detection + audio + drills key preview
const Map<String, Map<String, String>> kMonth3Translations = {
  'en': {
    'detection.title':    'Threat Detection',
    'detection.active':   'Detection Active',
    'detection.glass':    'Glass Break Detected',
    'audio.title':        'Audio Monitor',
    'audio.listening':    'Listening…',
    'drills.title':       'Safety Drills',
    'drills.run_now':     'Run Drill Now',
    'drills.complete':    'Drill Complete',
  },
  'hi': {
    'detection.title':    'खतरा पहचान',
    'detection.active':   'पहचान सक्रिय',
    'detection.glass':    'कांच टूटने की आवाज़ पहचानी',
    'audio.title':        'ऑडियो मॉनीटर',
    'audio.listening':    'सुन रहा है…',
    'drills.title':       'सुरक्षा अभ्यास',
    'drills.run_now':     'अभी अभ्यास चलाएं',
    'drills.complete':    'अभ्यास पूरा',
  },
  'ta': {
    'detection.title':    'அச்சுறுத்தல் கண்டறிதல்',
    'detection.active':   'கண்டறிதல் செயல்பாட்டில்',
    'detection.glass':    'கண்ணாடி உடைவு கண்டறியப்பட்டது',
    'audio.title':        'ஆடியோ கண்காணிப்பு',
    'audio.listening':    'கேட்கிறது…',
    'drills.title':       'பாதுகாப்பு பயிற்சிகள்',
    'drills.run_now':     'இப்போது பயிற்சி இயக்கு',
    'drills.complete':    'பயிற்சி முடிந்தது',
  },
  'te': {
    'detection.title':    'ముప్పు గుర్తింపు',
    'detection.active':   'గుర్తింపు సక్రియంగా ఉంది',
    'detection.glass':    'గాజు విరిగిన శబ్దం గుర్తించబడింది',
    'audio.title':        'ఆడియో మానిటర్',
    'audio.listening':    'వింటోంది…',
    'drills.title':       'భద్రతా అభ్యాసాలు',
    'drills.run_now':     'ఇప్పుడు అభ్యాసం నడపండి',
    'drills.complete':    'అభ్యాసం పూర్తైంది',
  },
  'ml': {
    'detection.title':    'ഭീഷണി കണ്ടെത്തൽ',
    'detection.active':   'കണ്ടെത്തൽ സക്രിയം',
    'detection.glass':    'ഗ്ലാസ് ഉടഞ്ഞത് കണ്ടെത്തി',
    'audio.title':        'ഓഡിയോ മോണിറ്റർ',
    'audio.listening':    'ശ്രവിക്കുന്നു…',
    'drills.title':       'സുരക്ഷാ പരിശീലനങ്ങൾ',
    'drills.run_now':     'ഇപ്പോൾ പരിശീലനം ആരംഭിക്കുക',
    'drills.complete':    'പരിശീലനം പൂർത്തിയായി',
  },
  'bn': {
    'detection.title':    'হুমকি সনাক্তকরণ',
    'detection.active':   'সনাক্তকরণ সক্রিয়',
    'detection.glass':    'কাচ ভাঙার শব্দ সনাক্ত হয়েছে',
    'audio.title':        'অডিও মনিটর',
    'audio.listening':    'শুনছে…',
    'drills.title':       'নিরাপত্তা মহড়া',
    'drills.run_now':     'এখনই মহড়া চালান',
    'drills.complete':    'মহড়া সম্পন্ন',
  },
  'mr': {
    'detection.title':    'धोका ओळख',
    'detection.active':   'ओळख सक्रिय',
    'detection.glass':    'काच तुटण्याचा आवाज ओळखला',
    'audio.title':        'ऑडिओ मॉनिटर',
    'audio.listening':    'ऐकत आहे…',
    'drills.title':       'सुरक्षा सराव',
    'drills.run_now':     'आत्ता सराव चालवा',
    'drills.complete':    'सराव पूर्ण',
  },
  'gu': {
    'detection.title':    'ખતरા શોધ',
    'detection.active':   'શોધ સક્રિય',
    'detection.glass':    'કાચ તૂટ્યાનો અવાજ મળ્યો',
    'audio.title':        'ઑડિઓ મૉનિટર',
    'audio.listening':    'સાંભળી રહ્યું છે…',
    'drills.title':       'સુરક્ષા કવાયત',
    'drills.run_now':     'હવે કવાયત ચલાવો',
    'drills.complete':    'કવાયત પૂર્ણ',
  },
  'pa': {
    'detection.title':    'ਖ਼ਤਰੇ ਦੀ ਪਛਾਣ',
    'detection.active':   'ਪਛਾਣ ਸਰਗਰਮ',
    'detection.glass':    'ਕੱਚ ਟੁੱਟਣ ਦੀ ਆਵਾਜ਼ ਮਿਲੀ',
    'audio.title':        'ਆਡੀਓ ਮਾਨੀਟਰ',
    'audio.listening':    'ਸੁਣ ਰਿਹਾ ਹੈ…',
    'drills.title':       'ਸੁਰੱਖਿਆ ਅਭਿਆਸ',
    'drills.run_now':     'ਹੁਣ ਅਭਿਆਸ ਚਲਾਓ',
    'drills.complete':    'ਅਭਿਆਸ ਪੂਰਾ',
  },
  'ur': {
    'detection.title':    'خطرے کی شناخت',
    'detection.active':   'شناخت فعال',
    'detection.glass':    'شیشہ ٹوٹنے کی آواز شناخت ہوئی',
    'audio.title':        'آڈیو مانیٹر',
    'audio.listening':    'سن رہا ہے…',
    'drills.title':       'حفاظتی مشقیں',
    'drills.run_now':     'ابھی مشق چلائیں',
    'drills.complete':    'مشق مکمل',
  },
  'ar': {
    'detection.title':    'الكشف عن التهديدات',
    'detection.active':   'الكشف نشط',
    'detection.glass':    'تم اكتشاف كسر زجاج',
    'audio.title':        'مراقبة الصوت',
    'audio.listening':    'يستمع…',
    'drills.title':       'التدريبات الأمنية',
    'drills.run_now':     'تشغيل التدريب الآن',
    'drills.complete':    'اكتمل التدريب',
  },
  'es': {
    'detection.title':    'Detección de amenazas',
    'detection.active':   'Detección activa',
    'detection.glass':    'Rotura de cristal detectada',
    'audio.title':        'Monitor de audio',
    'audio.listening':    'Escuchando…',
    'drills.title':       'Simulacros de seguridad',
    'drills.run_now':     'Ejecutar simulacro ahora',
    'drills.complete':    'Simulacro completado',
  },
  'fr': {
    'detection.title':    'Détection de menaces',
    'detection.active':   'Détection active',
    'detection.glass':    'Bris de verre détecté',
    'audio.title':        'Moniteur audio',
    'audio.listening':    'Écoute en cours…',
    'drills.title':       "Exercices de sécurité",
    'drills.run_now':     "Lancer l'exercice maintenant",
    'drills.complete':    'Exercice terminé',
  },
  'pt': {
    'detection.title':    'Detecção de ameaças',
    'detection.active':   'Detecção ativa',
    'detection.glass':    'Quebra de vidro detectada',
    'audio.title':        'Monitor de áudio',
    'audio.listening':    'Ouvindo…',
    'drills.title':       'Simulações de segurança',
    'drills.run_now':     'Executar simulação agora',
    'drills.complete':    'Simulação concluída',
  },
  'de': {
    'detection.title':    'Bedrohungserkennung',
    'detection.active':   'Erkennung aktiv',
    'detection.glass':    'Glasbruch erkannt',
    'audio.title':        'Audio-Monitor',
    'audio.listening':    'Hört zu…',
    'drills.title':       'Sicherheitsübungen',
    'drills.run_now':     'Übung jetzt starten',
    'drills.complete':    'Übung abgeschlossen',
  },
};

// Day 103 — coverage translations: onboarding + permissions + push sample keys
const Map<String, Map<String, String>> kCoverageTranslations = {
  'en': {
    'onboarding.step1_title': 'Welcome to ZapSafe',
    'onboarding.next':        'Next',
    'permissions.allow':      'Allow',
    'push.sos_title':         'SOS Alert',
  },
  'hi': {
    'onboarding.step1_title': 'ZapSafe में आपका स्वागत है',
    'onboarding.next':        'अगला',
    'permissions.allow':      'अनुमति दें',
    'push.sos_title':         'SOS अलर्ट',
  },
  'ta': {
    'onboarding.step1_title': 'ZapSafe-க்கு வரவேற்கிறோம்',
    'onboarding.next':        'அடுத்து',
    'permissions.allow':      'அனுமதி',
    'push.sos_title':         'SOS எச்சரிக்கை',
  },
  'te': {
    'onboarding.step1_title': 'ZapSafe కు స్వాగతం',
    'onboarding.next':        'తదుపరి',
    'permissions.allow':      'అనుమతించు',
    'push.sos_title':         'SOS హెచ్చరిక',
  },
  'ml': {
    'onboarding.step1_title': 'ZapSafe-ലേക്ക് സ്വാഗതം',
    'onboarding.next':        'അടുത്തത്',
    'permissions.allow':      'അനുവദിക്കുക',
    'push.sos_title':         'SOS അലേർട്ട്',
  },
  'bn': {
    'onboarding.step1_title': 'ZapSafe-এ স্বাগতম',
    'onboarding.next':        'পরবর্তী',
    'permissions.allow':      'অনুমতি দিন',
    'push.sos_title':         'SOS সতর্কতা',
  },
  'mr': {
    'onboarding.step1_title': 'ZapSafe मध्ये आपले स्वागत आहे',
    'onboarding.next':        'पुढे',
    'permissions.allow':      'परवानगी द्या',
    'push.sos_title':         'SOS अलर्ट',
  },
  'gu': {
    'onboarding.step1_title': 'ZapSafe માં આपका स्वागत है',
    'onboarding.next':        'આગળ',
    'permissions.allow':      'મંજૂરી આપો',
    'push.sos_title':         'SOS ચેતવણી',
  },
  'pa': {
    'onboarding.step1_title': 'ZapSafe ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ',
    'onboarding.next':        'ਅਗਲਾ',
    'permissions.allow':      'ਆਗਿਆ ਦਿਓ',
    'push.sos_title':         'SOS ਚੇਤਾਵਨੀ',
  },
  'ur': {
    'onboarding.step1_title': 'ZapSafe میں آپ کا خیر مقدم ہے',
    'onboarding.next':        'اگلا',
    'permissions.allow':      'اجازت دیں',
    'push.sos_title':         'SOS الرٹ',
  },
  'ar': {
    'onboarding.step1_title': 'مرحباً بك في ZapSafe',
    'onboarding.next':        'التالي',
    'permissions.allow':      'السماح',
    'push.sos_title':         'تنبيه SOS',
  },
  'es': {
    'onboarding.step1_title': 'Bienvenido a ZapSafe',
    'onboarding.next':        'Siguiente',
    'permissions.allow':      'Permitir',
    'push.sos_title':         'Alerta SOS',
  },
  'fr': {
    'onboarding.step1_title': 'Bienvenue sur ZapSafe',
    'onboarding.next':        'Suivant',
    'permissions.allow':      'Autoriser',
    'push.sos_title':         'Alerte SOS',
  },
  'pt': {
    'onboarding.step1_title': 'Bem-vindo ao ZapSafe',
    'onboarding.next':        'Próximo',
    'permissions.allow':      'Permitir',
    'push.sos_title':         'Alerta SOS',
  },
  'de': {
    'onboarding.step1_title': 'Willkommen bei ZapSafe',
    'onboarding.next':        'Weiter',
    'permissions.allow':      'Erlauben',
    'push.sos_title':         'SOS-Alarm',
  },
};

// ─── State ─────────────────────────────────────────────────────────────────────

class I18nState {
  const I18nState({required this.selectedCode});

  final String selectedCode;

  LangInfo get lang =>
      kSupportedLanguages.firstWhere((l) => l.code == selectedCode,
          orElse: () => kSupportedLanguages.first);

  bool get isRtl => lang.rtl;

  Map<String, String> get demoStrings =>
      kDemoTranslations[selectedCode] ?? kDemoTranslations['en']!;

  /// Day 107 — alerts / vault / profile preview keys (also in assets/translations/*.json).
  Map<String, String> get month4Strings =>
      kMonth4Translations[selectedCode] ?? kMonth4Translations['en']!;

  List<String> get alertLifecycle =>
      kAlertLifecycle[selectedCode] ?? kAlertLifecycle['en']!;

  I18nState copyWith({String? selectedCode}) =>
      I18nState(selectedCode: selectedCode ?? this.selectedCode);
}

// ─── Notifier ──────────────────────────────────────────────────────────────────

class I18nNotifier extends StateNotifier<I18nState> {
  I18nNotifier() : super(const I18nState(selectedCode: 'en'));

  void select(String code) => state = state.copyWith(selectedCode: code);
}

// ─── Provider ──────────────────────────────────────────────────────────────────

final i18nProvider = StateNotifierProvider<I18nNotifier, I18nState>(
  (ref) => I18nNotifier(),
);

// ─── Day 305 — real app-locale bridge ──────────────────────────────────────
//
// [i18nProvider] above is a self-contained Day 102-108 demo (never read by
// the real app shell). The REAL active locale lives in EasyLocalization's
// `context.locale`, set app-wide in `main.dart`. Dio interceptors run
// outside the widget tree and can't call `context.locale` directly, so
// `ZapSafeApp` pushes the current code into this plain `StateProvider` on
// every rebuild (see `main.dart`), and `api_client.dart`'s
// `LanguageCodeProvider` callback reads it — same "callback reads a
// Riverpod-backed value" pattern already used for `AccessTokenProvider`.
final currentLanguageCodeProvider = StateProvider<String>((ref) => 'en');
